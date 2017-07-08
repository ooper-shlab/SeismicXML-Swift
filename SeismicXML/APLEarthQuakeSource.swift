//
//  APLEarthQuakeSource.swift
//  SeismicXML
//
//  Translated by OOPer in cooperation with shlab.jp, on 2016/1/12.
//
//
/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information

 Abstract:
 Data source object responsible for initiating the download of the XML data and parses the Earthquake objects at view load time.
 */

import Foundation

@objc(APLEarthQuakeSource)
class APLEarthQuakeSource: NSObject {
    
    @objc private(set) dynamic var earthquakes: [Earthquake] = []
    @objc private(set) dynamic var error: Error?
    
    private let feedURLString = "https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/all_week.quakeml"
    
    private var sessionTask: URLSessionDataTask?
    
    private var addEarthQuakesObserver: AnyObject!
    private var earthQuakesErrorObserver: AnyObject!
    
    // queue that manages our NSOperation for parsing earthquake data
    private var parseQueue: OperationQueue?
    
    
    //MARK: -
    
    override init() {
        
        super.init()
        
        // Our NSNotification callback from the running NSOperation to add the earthquakes
        addEarthQuakesObserver = NotificationCenter.default.addObserver(forName: ParseOperation.AddEarthQuakesNotificationName, object: nil, queue: nil) {notification in
            /**
             The NSOperation "ParseOperation" calls this observer with batches of parsed objects.
             The batch size is set via the kSizeOfEarthquakeBatch constant. Use KVO to notify our client.
             */
            let incomingEarthquakes = notification.userInfo![ParseOperation.EarthquakeResultsKey] as! [Earthquake]
            
            self.willChangeValue(forKey: "earthquakes")
            self.earthquakes.append(contentsOf: incomingEarthquakes)
        }
        
        // Our NSNotification callback from the running NSOperation when a parsing error has occurred
        earthQuakesErrorObserver = NotificationCenter.default.addObserver(forName: ParseOperation.EarthquakesErrorNotificationName, object: nil, queue: nil) {notification in
            // The NSOperation "ParseOperation" calls this observer with an error, use KVO to notify our client
            self.willChangeValue(forKey: "error")
            self.error = (notification.userInfo![ParseOperation.EarthquakesMessageErrorKey] as! Error)
            self.didChangeValue(forKey: "error")
        }
        
        parseQueue = OperationQueue()
        
    }
    
    func startEarthQuakeLookup() {
        /*
        Use NSURLSession to asynchronously download the data.
        This means the main thread will not be blocked - the application will remain responsive to the user.
        
        IMPORTANT! The main thread of the application should never be blocked!
        Also, avoid synchronous network access on any thread.
        */
        
        let earthquakeURLRequest = URLRequest(url: URL(string: feedURLString)!)
        
        // create an session data task to obtain and download the app icon
        sessionTask = URLSession.shared.dataTask(with: earthquakeURLRequest, completionHandler: {data, response, error in
                
                OperationQueue.main.addOperation {
                    
                    // back on the main thread, check for errors, if no errors start the parsing
                    //
                    if let error = error, response == nil {
                        let isATSError: Bool
                        if #available(iOS 9.0, *) {
                            isATSError = (error as NSError).code == NSURLErrorAppTransportSecurityRequiresSecureConnection
                        } else {
                            isATSError = false
                        }
                        if isATSError {
                            
                            // if you get error NSURLErrorAppTransportSecurityRequiresSecureConnection (-1022),
                            // then your Info.plist has not been properly configured to match the target server.
                            //
                            fatalError("NSURLErrorAppTransportSecurityRequiresSecureConnection")
                        } else {
                            // use KVO to notify our client of this error
                            self.willChangeValue(forKey: "error")
                            self.error = error
                            self.didChangeValue(forKey: "error")
                        }
                    }
                    
                    // here we check for any returned NSError from the server,
                    // "and" we also check for any http response errors check for any response errors
                    if let httpResponse = response as? HTTPURLResponse {
                        
                        if httpResponse.statusCode/100 == 2 && response!.mimeType == "application/xml" {
                            
                            /* Update the UI and start parsing the data,
                            Spawn an NSOperation to parse the earthquake data so that the UI is not
                            blocked while the application parses the XML data.
                            */
                            let parseOperation = ParseOperation(data: data!)
                            self.parseQueue?.addOperation(parseOperation)
                        } else {
                            let errorString =
                            NSLocalizedString("HTTP Error", comment: "Error message displayed when receiving an error from the server.")
                            let userInfo = [NSLocalizedDescriptionKey : errorString]
                            
                            // use KVO to notify our client of this error
                            self.willChangeValue(forKey: "error")
                            self.error = NSError(domain: "HTTP",
                                code: httpResponse.statusCode,
                                userInfo: userInfo)
                            self.didChangeValue(forKey: "error")
                        }
                    }
                }
        })            

        
        self.sessionTask?.resume()
    }
    
    deinit {
        
        NotificationCenter.default.removeObserver(self.addEarthQuakesObserver)
        NotificationCenter.default.removeObserver(self.earthQuakesErrorObserver)
    }
    
}
