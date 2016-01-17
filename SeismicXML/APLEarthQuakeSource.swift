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
    
    private(set) dynamic var earthquakes: [Earthquake] = []
    private(set) dynamic var error: NSError?
    
    private let feedURLString = "http://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/all_week.quakeml"
    
    private var sessionTask: NSURLSessionDataTask?
    
    private var addEarthQuakesObserver: AnyObject!
    private var earthQuakesErrorObserver: AnyObject!
    
    // queue that manages our NSOperation for parsing earthquake data
    private var parseQueue: NSOperationQueue?
    
    
    //MARK: -
    
    override init() {
        
        super.init()
        
        // Our NSNotification callback from the running NSOperation to add the earthquakes
        addEarthQuakesObserver = NSNotificationCenter.defaultCenter().addObserverForName(ParseOperation.AddEarthQuakesNotificationName, object: nil, queue: nil) {notification in
            /**
             The NSOperation "ParseOperation" calls this observer with batches of parsed objects.
             The batch size is set via the kSizeOfEarthquakeBatch constant. Use KVO to notify our client.
             */
            let incomingEarthquakes = notification.userInfo![ParseOperation.EarthquakeResultsKey] as! [Earthquake]
            
            self.willChangeValueForKey("earthquakes")
            self.earthquakes.appendContentsOf(incomingEarthquakes)
        }
        
        // Our NSNotification callback from the running NSOperation when a parsing error has occurred
        earthQuakesErrorObserver = NSNotificationCenter.defaultCenter().addObserverForName(ParseOperation.EarthquakesErrorNotificationName, object: nil, queue: nil) {notification in
            // The NSOperation "ParseOperation" calls this observer with an error, use KVO to notify our client
            self.willChangeValueForKey("error")
            self.error = (notification.userInfo![ParseOperation.EarthquakesMessageErrorKey] as! NSError)
            self.didChangeValueForKey("error")
        }
        
        parseQueue = NSOperationQueue()
        
    }
    
    func startEarthQuakeLookup() {
        /*
        Use NSURLSession to asynchronously download the data.
        This means the main thread will not be blocked - the application will remain responsive to the user.
        
        IMPORTANT! The main thread of the application should never be blocked!
        Also, avoid synchronous network access on any thread.
        */
        
        let earthquakeURLRequest = NSURLRequest(URL: NSURL(string: feedURLString)!)
        
        // create an session data task to obtain and download the app icon
        sessionTask = NSURLSession.sharedSession().dataTaskWithRequest(earthquakeURLRequest)
            {data, response, error in
                
                NSOperationQueue.mainQueue().addOperationWithBlock {
                    
                    // back on the main thread, check for errors, if no errors start the parsing
                    //
                    if let error = error where response == nil {
                        let isATSError: Bool
                        if #available(iOS 9.0, *) {
                            isATSError = (error.code == NSURLErrorAppTransportSecurityRequiresSecureConnection)
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
                            self.willChangeValueForKey("error")
                            self.error = error
                            self.didChangeValueForKey("error")
                        }
                    }
                    
                    // here we check for any returned NSError from the server,
                    // "and" we also check for any http response errors check for any response errors
                    if let httpResponse = response as? NSHTTPURLResponse {
                        
                        if ((httpResponse.statusCode/100) == 2) && response!.MIMEType == "application/xml" {
                            
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
                            self.willChangeValueForKey("error")
                            self.error = NSError(domain: "HTTP",
                                code: httpResponse.statusCode,
                                userInfo: userInfo)
                            self.didChangeValueForKey("error")
                        }
                    }
                }
        }
        
        self.sessionTask?.resume()
    }
    
    deinit {
        
        NSNotificationCenter.defaultCenter().removeObserver(self.addEarthQuakesObserver)
        NSNotificationCenter.defaultCenter().removeObserver(self.earthQuakesErrorObserver)
    }
    
}