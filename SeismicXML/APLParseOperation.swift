//
//  APLParseOperation.swift
//  SeismicXML
//
//  Translated by OOPer in cooperation with shlab.jp, on 2014/09/13.
//  
//
/*
     File: APLParseOperation.h
     File: APLParseOperation.m
 Abstract: The NSOperation class used to perform the XML parsing of earthquake data.
  Version: 3.5

 Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple
 Inc. ("Apple") in consideration of your agreement to the following
 terms, and your use, installation, modification or redistribution of
 this Apple software constitutes acceptance of these terms.  If you do
 not agree with these terms, please do not use, install, modify or
 redistribute this Apple software.

 In consideration of your agreement to abide by the following terms, and
 subject to these terms, Apple grants you a personal, non-exclusive
 license, under Apple's copyrights in this original Apple software (the
 "Apple Software"), to use, reproduce, modify and redistribute the Apple
 Software, with or without modifications, in source and/or binary forms;
 provided that if you redistribute the Apple Software in its entirety and
 without modifications, you must retain this notice and the following
 text and disclaimers in all such redistributions of the Apple Software.
 Neither the name, trademarks, service marks or logos of Apple Inc. may
 be used to endorse or promote products derived from the Apple Software
 without specific prior written permission from Apple.  Except as
 expressly stated in this notice, no other rights or licenses, express or
 implied, are granted by Apple herein, including but not limited to any
 patent rights that may be infringed by your derivative works or by other
 works in which the Apple Software may be incorporated.

 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
 MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
 THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
 FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
 OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.

 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
 OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
 MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
 AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
 STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.

 Copyright (C) 2014 Apple Inc. All Rights Reserved.

 */
import UIKit

// NSNotification name for sending earthquake data back to the app delegate
let kAddEarthquakesNotificationName = "AddEarthquakesNotif"
// NSNotification userInfo key for obtaining the earthquake data
let kEarthquakeResultsKey = "EarthquakeResultsKey"

// NSNotification name for reporting errors
let kEarthquakesErrorNotificationName = "EarthquakeErrorNotif"
// NSNotification userInfo key for obtaining the error message
let kEarthquakesMessageErrorKey = "EarthquakesMsgErrorKey"


@objc(APLParseOperation)
class ParseOperation: NSOperation, NSXMLParserDelegate {
    
    let earthquakeData: NSData
    
    
    private var currentEarthquakeObject: Earthquake!
    private var currentParseBatch = [Earthquake]()
    private var currentParsedCharacterData: String = ""
    
    
    private let _dateFormatter: NSDateFormatter
    
    private var _accumulatingParsedCharacterData: Bool = false
    private var _didAbortParsing: Bool = false
    private var _parsedEarthquakesCounter: Int = 0
    
    
    init(data parseData: NSData) {
        
        earthquakeData = parseData.copy() as! NSData
        
        _dateFormatter = NSDateFormatter()
        _dateFormatter.timeZone = NSTimeZone(forSecondsFromGMT: 0)
        _dateFormatter.locale = NSLocale(localeIdentifier: "en_US_POSIX")
        _dateFormatter.dateFormat = "yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'"
        
        super.init()
    }
    
    
    private func addEarthquakesToList(earthquakes: [Earthquake]) {
        
        assert(NSThread.isMainThread())
        NSNotificationCenter.defaultCenter().postNotificationName(kAddEarthquakesNotificationName, object: self, userInfo: [kEarthquakeResultsKey: earthquakes])
    }
    
    
    // The main function for this NSOperation, to start the parsing.
    override func main() {
        
        /*
        It's also possible to have NSXMLParser download the data, by passing it a URL, but this is not desirable because it gives less control over the network, particularly in responding to connection errors.
        */
        let parser = NSXMLParser(data: self.earthquakeData)
        parser.delegate = self
        parser.parse()
        
        /*
        Depending on the total number of earthquakes parsed, the last batch might not have been a "full" batch, and thus not been part of the regular batch transfer. So, we check the count of the array and, if necessary, send it to the main thread.
        */
        if self.currentParseBatch.count > 0 {
            let parseBatch = self.currentParseBatch
            dispatch_async(dispatch_get_main_queue()) {
                self.addEarthquakesToList(parseBatch)
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
    private let kEntryElementName = "entry"
    private let kLinkElementName = "link"
    private let kTitleElementName = "title"
    private let kUpdatedElementName = "updated"
    private let kGeoRSSPointElementName = "georss:point"
    
    
    //MARK: - NSXMLParser delegate methods
    
    func parser(parser: NSXMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [NSObject : AnyObject]) {
        
        /*
        If the number of parsed earthquakes is greater than kMaximumNumberOfEarthquakesToParse, abort the parse.
        */
        if _parsedEarthquakesCounter >= kMaximumNumberOfEarthquakesToParse {
            /*
            Use the flag didAbortParsing to distinguish between this deliberate stop and other parser errors.
            */
            _didAbortParsing = true
            parser.abortParsing()
        }
        if elementName == kEntryElementName {
            let earthquake = Earthquake()
            self.currentEarthquakeObject = earthquake
        } else if elementName == kLinkElementName {
            if let relAttribute: AnyObject = attributeDict["rel"] {
                if relAttribute as! NSString == "alternate" {
                    let USGSWebLink = attributeDict["href"]! as! String
                    self.currentEarthquakeObject.USGSWebLink = NSURL(string: USGSWebLink)
                }
            }
        } else if elementName == kTitleElementName || elementName == kUpdatedElementName || elementName == kGeoRSSPointElementName {
            // For the 'title', 'updated', or 'georss:point' element begin accumulating parsed character data.
            // The contents are collected in parser:foundCharacters:.
            _accumulatingParsedCharacterData = true
            // The mutable string needs to be reset to empty.
            self.self.currentParsedCharacterData = ""
        }
    }
    
    func parser(parser: NSXMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        
        if elementName == kEntryElementName {
            
            self.currentParseBatch.append(self.currentEarthquakeObject)
            _parsedEarthquakesCounter++
            if self.currentParseBatch.count >= kSizeOfEarthquakeBatch {
                let parseBatch = self.currentParseBatch
                dispatch_async(dispatch_get_main_queue()) {
                    self.addEarthquakesToList(parseBatch)
                }
                self.currentParseBatch = []
            }
        } else if elementName == kTitleElementName {
            /*
            The title element contains the magnitude and location in the following format:
            <title>M 3.6, Virgin Islands region<title/>
            Extract the magnitude and the location using a scanner:
            */
            let scanner = NSScanner(string: self.currentParsedCharacterData)
            // Scan past the "M " before the magnitude.
            if scanner.scanString("M ", intoString: nil) {
                var magnitude: Float = 0.0
                if scanner.scanFloat(&magnitude) {
                    self.currentEarthquakeObject.magnitude = CGFloat(magnitude)
                    // Scan past the ", " before the title.
                    if scanner.scanString(", ", intoString: nil) {
                        var location: NSString? = nil
                        // Scan the remainer of the string.
                        if scanner.scanUpToCharactersFromSet(NSCharacterSet.illegalCharacterSet(), intoString: &location) {
                            self.currentEarthquakeObject.location = location! as String
                        }
                    }
                }
            }
        } else if elementName == kUpdatedElementName {
            if self.currentEarthquakeObject != nil {
                self.currentEarthquakeObject.date = _dateFormatter.dateFromString(self.currentParsedCharacterData)
            } else {
                // kUpdatedElementName can be found outside an entry element (i.e. in the XML header)
                // so don't process it here.
            }
        } else if elementName == kGeoRSSPointElementName {
            // The georss:point element contains the latitude and longitude of the earthquake epicenter.
            // 18.6477 -66.7452
            //
            let scanner = NSScanner(string: self.currentParsedCharacterData)
            var latitude = 0.0, longitude = 0.0
            if scanner.scanDouble(&latitude) {
                if scanner.scanDouble(&longitude) {
                    self.currentEarthquakeObject.latitude = latitude
                    self.currentEarthquakeObject.longitude = longitude
                }
            }
        }
        // Stop accumulating parsed character data. We won't start again until specific elements begin.
        _accumulatingParsedCharacterData = false
    }
    
    /**
    This method is called by the parser when it find parsed character data ("PCDATA") in an element. The parser is not guaranteed to deliver all of the parsed character data for an element in a single invocation, so it is necessary to accumulate character data until the end of the element is reached.
    */
    func parser(parser: NSXMLParser, foundCharacters string: String?) {
        
        if _accumulatingParsedCharacterData {
            // If the current element is one whose content we care about, append 'string'
            // to the property that holds the content of the current element.
            //
            self.currentParsedCharacterData += string!
        }
    }
    
    /**
    An error occurred while parsing the earthquake data: post the error as an NSNotification to our app delegate.
    */
    private func handleEarthquakesError(parseError: NSError) {
        
        assert(NSThread.isMainThread())
        NSNotificationCenter.defaultCenter().postNotificationName(kEarthquakesErrorNotificationName, object: self, userInfo: [kEarthquakesMessageErrorKey: parseError])
    }
    
    /**
    An error occurred while parsing the earthquake data, pass the error to the main thread for handling.
    (Note: don't report an error if we aborted the parse due to a max limit of earthquakes.)
    */
    func parser(parser: NSXMLParser, parseErrorOccurred parseError: NSError) {
        
        if parseError.code != NSXMLParserError.DelegateAbortedParseError.rawValue && !_didAbortParsing {
            dispatch_async(dispatch_get_main_queue()) {
                self.handleEarthquakesError(parseError)
            }
        }
    }
    
    
}