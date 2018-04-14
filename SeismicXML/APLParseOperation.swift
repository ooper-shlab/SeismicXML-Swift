//
//  APLParseOperation.swift
//  SeismicXML
//
//  Translated by OOPer in cooperation with shlab.jp, on 2014/09/13.
//  
//
/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information

 Abstract:
 The NSOperation class used to perform the XML parsing of earthquake data.
 */


import UIKit


@objc(APLParseOperation)
class ParseOperation: Operation, XMLParserDelegate {
    
    let earthquakeData: Data
    
    static let AddEarthQuakesNotificationName =  Notification.Name("AddEarthquakesNotif")       // NSNotification name for sending earthquake data back to the app delegate
    static let EarthquakeResultsKey = "EarthquakeResultsKey"                 // NSNotification userInfo key for obtaining the earthquake data
    
    static let EarthquakesErrorNotificationName = Notification.Name("EarthquakeErrorNotif")     // NSNotification name for reporting errors
    static let EarthquakesMessageErrorKey = "EarthquakesMsgErrorKey"           // NSNotification userInfo key for obtaining the error message
    
    private var currentEarthquakeObject: Earthquake!
    private var currentParseBatch: [Earthquake] = []
    private var currentParsedCharacterData: String = ""
    
    private let dateFormatter: DateFormatter
    
    private var accumulatingParsedCharacterData: Bool = false
    private var didAbortParsing: Bool = false
    
    private var parsedEarthquakesCounter: Int = 0
    
    private var seekDescription: Bool = false
    private var seekTime: Bool = false
    private var seekLatitude: Bool = false
    private var seekLongitude: Bool = false
    private var seekMagnitude: Bool = false
    
    // a stack queue containing  elements as they are being parsed, used to detect malformed XML.
    private var elementStack: [String] = []
    
    
    override init() {
        fatalError("Invalid use of init; use initWithData to create APLParseOperation")
    }
    
    init(data parseData: Data) {
        
        earthquakeData = parseData
        
        dateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        
        // 2015-09-24T16:01:00.283Z
        
        super.init()
    }
    
    
    private func addEarthquakesToList(_ earthquakes: [Earthquake]) {
        
        assert(Thread.isMainThread)
        NotificationCenter.default.post(name: ParseOperation.AddEarthQuakesNotificationName,
            object: self,
            userInfo: [ParseOperation.EarthquakeResultsKey: earthquakes])
    }
    
    
    // The main function for this NSOperation, to start the parsing.
    override func main() {
        
        /*
        It's also possible to have NSXMLParser download the data, by passing it a URL, but this is not desirable because it gives less control over the network, particularly in responding to connection errors.
        */
        let parser = XMLParser(data: self.earthquakeData)
        parser.delegate = self
        parser.parse()
        
        /*
        Depending on the total number of earthquakes parsed, the last batch might not have been a "full" batch, and thus not been part of the regular batch transfer. So, we check the count of the array and, if necessary, send it to the main thread.
        */
        if !self.currentParseBatch.isEmpty {
            DispatchQueue.main.async {
                self.addEarthquakesToList(self.currentParseBatch)
            }
        }
    }
    
    
    //MARK: - Parser constants
    
    /*
    Limit the number of parsed earthquakes to 50 (a given day may have more than 50 earthquakes around the world, so we only take the first 50).
    */
    private let kMaximumNumberOfEarthquakesToParse = 50
    
    /*
    When an Earthquake object has been fully constructed, it must be passed to the main thread and the table view in RootViewController must be reloaded to display it. It is not efficient to do this for every Earthquake object - the overhead in communicating between the threads and reloading the table exceed the benefit to the user. Instead, we pass the objects in batches, sized by the constant below. In your application, the optimal batch size will vary depending on the amount of data in the object and other factors, as appropriate.
    */
    private let kSizeOfEarthquakeBatch = 10
    
    // Reduce potential parsing errors by using string constants declared in a single place.
    private let kValueKey = "value"
    
    private let kEntryElementName = "event"
    
    private let kDescriptionElementDesc = "description"
    private let kDescriptionElementContent = "text"
    
    private let kTimeElementName = "time";
    
    private let kLatitudeElementName = "latitude";
    private let kLongitudeElementName = "longitude";
    
    private let kMagitudeValueName = "mag";
    
    
    //MARK: - NSXMLParser delegate methods
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String]) {
        
        // add the element to the state stack
        self.elementStack.append(elementName)
        
        /*
        If the number of parsed earthquakes is greater than kMaximumNumberOfEarthquakesToParse, abort the parse.
        */
        if parsedEarthquakesCounter >= kMaximumNumberOfEarthquakesToParse {
            // Use the flag didAbortParsing to distinguish between this deliberate stop and other parser errors
            didAbortParsing = true
            parser.abortParsing()
        }
        
        if elementName == kEntryElementName {
            let earthquake = Earthquake()
            self.currentEarthquakeObject = earthquake
        } else if (self.seekDescription && elementName == kDescriptionElementContent) ||  // <description>..<text>
        (self.seekTime && elementName == kValueKey) ||                          // <time>..<value>
        (self.seekLatitude && elementName == kValueKey) ||              // <latitude>..<value>
        (self.seekLongitude && elementName == kValueKey) ||             // <longitude>..<value>
        (self.seekMagnitude && elementName == kValueKey)               // <mag>..<value>
        {
                    // For elements: <text> and <value>, the contents are collected in parser:foundCharacters:
            accumulatingParsedCharacterData = true
                    // The mutable string needs to be reset to empty.
            self.currentParsedCharacterData = ""
        } else if elementName == kDescriptionElementDesc {
            seekDescription = true
        } else if elementName == kTimeElementName {
            seekTime = true
        } else if elementName == kLatitudeElementName {
            seekLatitude = true
        } else if elementName == kLongitudeElementName {
            seekLongitude = true
        } else if elementName == kMagitudeValueName {
            seekMagnitude = true
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        
            // check if the end element matches what's last on the element stack
        if elementName == self.elementStack.last {
                // they match, remove it
            self.elementStack.removeLast()
        } else {
                // they don't match, we have malformed XML
            NSLog("could not find end element of \"%@\"", elementName)
            self.elementStack.removeAll()
            parser.abortParsing()
        }
        
        switch elementName {
        case kEntryElementName:
        
                // end earthquake entry, add it to the array
            self.currentParseBatch.append(self.currentEarthquakeObject)
            parsedEarthquakesCounter += 1

            if self.currentParseBatch.count >= kSizeOfEarthquakeBatch {
                DispatchQueue.main.sync {
                    self.addEarthquakesToList(self.currentParseBatch)
                }

                self.currentParseBatch.removeAll()
            }
        case kDescriptionElementContent:
                // end description, set the location of the earthquake
            if self.seekDescription {
                    /*
                     The description element contains the following format:
                        "14km WNW of Anza, California"
                     Extract just the location name
                     */
        
                    // search the entire string for "of ", and extract that last part of that string
                let searchedRange = NSRange(0..<self.currentParsedCharacterData.utf16.count)
                let regExpression = try! NSRegularExpression(pattern: "of ", options: [])
                if let match = regExpression.firstMatch(in: self.currentParsedCharacterData, options: [], range: searchedRange) {
                    let extractRange = Range(match.range, in: self.currentParsedCharacterData)
                    self.currentEarthquakeObject.location = String(self.currentParsedCharacterData[extractRange!])
                } else {print("missing 'of ' in \(kDescriptionElementContent) element")}

                seekDescription = false
            }
        case kValueKey:
            if self.seekTime {
                    // end earthquake date/time
                self.currentEarthquakeObject.date = self.dateFormatter.date(from: self.currentParsedCharacterData)
                seekTime = false
            } else if self.seekLatitude {
                    // end earthquake latitude
                self.currentEarthquakeObject.latitude = Double(self.currentParsedCharacterData) ?? 0.0
                seekLatitude = false
            } else if self.seekLongitude {
                    // end earthquake longitude
                self.currentEarthquakeObject.longitude = Double(self.currentParsedCharacterData) ?? 0.0
                seekLongitude = false
            } else if self.seekMagnitude {
                    // end earthquake magnitude
                self.currentEarthquakeObject.magnitude = Float(self.currentParsedCharacterData) ?? 0.0
                seekMagnitude = false
            }
        default:
            break
        }
        
        // Stop accumulating parsed character data. We won't start again until specific elements begin.
        accumulatingParsedCharacterData = false
    }
    
    /**
    This method is called by the parser when it find parsed character data ("PCDATA") in an element. The parser is not guaranteed to deliver all of the parsed character data for an element in a single invocation, so it is necessary to accumulate character data until the end of the element is reached.
    */
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        
        if accumulatingParsedCharacterData {
            // If the current element is one whose content we care about, append 'string'
            // to the property that holds the content of the current element.
            //
            self.currentParsedCharacterData += string
        }
    }
    
    /**
    An error occurred while parsing the earthquake data: post the error as an NSNotification to our app delegate.
    */
    private func handleEarthquakesError(_ parseError: Error) {
        
        assert(Thread.isMainThread)
        NotificationCenter.default.post(name: ParseOperation.EarthquakesErrorNotificationName, object: self, userInfo: [ParseOperation.EarthquakesMessageErrorKey: parseError])
    }
    
    /**
    An error occurred while parsing the earthquake data, pass the error to the main thread for handling.
    (Note: don't report an error if we aborted the parse due to a max limit of earthquakes.)
    */
    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        
        if (parseError as NSError).code != XMLParser.ErrorCode.delegateAbortedParseError.rawValue && !didAbortParsing {
            DispatchQueue.main.async {
                self.handleEarthquakesError(parseError)
            }
        }
    }
    
    
}
