//
//  APLViewController.swift
//  SeismicXML
//
//  Translated by OOPer in cooperation with shlab.jp, on 2014/09/13.
//
//

/*
     File: APLViewController.h
     File: APLViewController.m
 Abstract: View controller for displaying the earthquake list; initiates the download of the XML data and parses the Earthquake objects at view load time.
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
// this framework is imported so we can use the kCFURLErrorNotConnectedToInternet error code
import CFNetwork
import MapKit

@objc(APLViewController)
class ViewController: UITableViewController, UIActionSheetDelegate {
    
    private var earthquakeList = [Earthquake]()
    
    // queue that manages our NSOperation for parsing earthquake data
    private var parseQueue: NSOperationQueue!
    
    
    //MARK: -
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        /*
        Use NSURLConnection to asynchronously download the data. This means the main thread will not be blocked - the application will remain responsive to the user.
        
        IMPORTANT! The main thread of the application should never be blocked!
        Also, avoid synchronous network access on any thread.
        */
        let feedURLString = "http://earthquake.usgs.gov/eqcenter/catalogs/7day-M2.5.xml"
        
        let earthquakeURLRequest = NSURLRequest(URL: NSURL(string: feedURLString)!)
        
        // send the async request (note that the completion block will be called on the main thread)
        //
        // note: using the block-based "sendAsynchronousRequest" is preferred, and useful for
        // small data transfers that are likely to succeed. If you doing large data transfers,
        // consider using the NSURLConnectionDelegate-based APIs.
        //
        NSURLConnection.sendAsynchronousRequest(earthquakeURLRequest,
            queue: NSOperationQueue.mainQueue()) {(response, data, error) in
                // the NSOperationQueue upon which the handler block will be dispatched:
                
                // back on the main thread, check for errors, if no errors start the parsing
                //
                UIApplication.sharedApplication().networkActivityIndicatorVisible = false
                
                // here we check for any returned NSError from the server, "and" we also check for any http response errors
                if error != nil {
                    self.handleError(error!)
                } else {
                    // check for any response errors
                    let httpResponse = response as NSHTTPURLResponse
                    if httpResponse.statusCode / 100 == 2 && response.MIMEType == "application/atom+xml" {
                        
                        // Update the UI and start parsing the data,
                        // Spawn an NSOperation to parse the earthquake data so that the UI is not
                        // blocked while the application parses the XML data.
                        //
                        let parseOperation = ParseOperation(data: data)
                        self.parseQueue.addOperation(parseOperation)
                    } else {
                        let errorString = NSLocalizedString("HTTP Error", comment: "Error message displayed when receving a connection error.")
                        let userInfo: NSDictionary = [NSLocalizedDescriptionKey: errorString]
                        let reportError = NSError(domain: "HTTP", code: httpResponse.statusCode, userInfo: userInfo)
                        self.handleError(reportError)
                    }
                }
        }
        
        // Start the status bar network activity indicator.
        // We'll turn it off when the connection finishes or experiences an error.
        //
        UIApplication.sharedApplication().networkActivityIndicatorVisible = true
        
        self.parseQueue = NSOperationQueue()
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "addEarthquakes:", name: kAddEarthquakesNotificationName, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "earthquakesError:", name: kEarthquakesErrorNotificationName, object: nil)
        
        // if the locale changes behind our back, we need to be notified so we can update the date
        // format in the table view cells
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "localeChanged:", name: NSCurrentLocaleDidChangeNotification, object: nil)
    }
    
    deinit {
        
        // we are no longer interested in these notifications:
        NSNotificationCenter.defaultCenter().removeObserver(self, name: kAddEarthquakesNotificationName, object: nil)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: kEarthquakesErrorNotificationName, object: nil)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: NSCurrentLocaleDidChangeNotification, object: nil)
    }
    
    /**
    Handle errors in the download by showing an alert to the user. This is a very simple way of handling the error, partly because this application does not have any offline functionality for the user. Most real applications should handle the error in a less obtrusive way and provide offline functionality to the user.
    */
    private func handleError(error: NSError) {
        
        let errorMessage = error.localizedDescription
        let alertTitle = NSLocalizedString("Error", comment: "Title for alert displayed when download or parse error occurs.")
        let okTitle = NSLocalizedString("OK ", comment: "OK Title for alert displayed when download or parse error occurs.")
        
        let alertView = UIAlertView(title: alertTitle, message: errorMessage, delegate: nil, cancelButtonTitle: okTitle)
        alertView.show()
    }
    
    /**
    Our NSNotification callback from the running NSOperation to add the earthquakes
    */
    func addEarthquakes(notif: NSNotification) {
        
        assert(NSThread.isMainThread())
        self.addEarthquakesToList(notif.userInfo![kEarthquakeResultsKey]! as [Earthquake])
    }
    
    /**
    Our NSNotification callback from the running NSOperation when a parsing error has occurred
    */
    func earthquakesError(notif: NSNotification) {
        
        assert(NSThread.isMainThread())
        self.handleError(notif.userInfo![kEarthquakesMessageErrorKey]! as NSError)
    }
    
    /**
    The NSOperation "ParseOperation" calls addEarthquakes: via NSNotification, on the main thread which in turn calls this method, with batches of parsed objects. The batch size is set via the kSizeOfEarthquakeBatch constant.
    */
    func addEarthquakesToList(earthquakes: [Earthquake]) {
        
        let startingRow = self.earthquakeList.count
        let earthquakeCount = earthquakes.count
        let indexPaths = NSMutableArray(capacity: earthquakeCount)
        
        for row in startingRow..<startingRow + earthquakeCount {
            
            let indexPath = NSIndexPath(forRow: row, inSection: 0)
            indexPaths.addObject(indexPath)
        }
        
        self.earthquakeList += earthquakes
        
        self.tableView.insertRowsAtIndexPaths(indexPaths, withRowAnimation: .Automatic)
    }
    
    
    //MARK: - UITableViewDelegate
    
    // The number of rows is equal to the number of earthquakes in the array.
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        return self.earthquakeList.count
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        
        let kEarthquakeCellID = "EarthquakeCellID"
        let cell = tableView.dequeueReusableCellWithIdentifier(kEarthquakeCellID) as EarthquakeTableViewCell
        
        // Get the specific earthquake for this row.
        let earthquake = self.earthquakeList[indexPath.row]
        
        cell.configureWithEarthquake(earthquake)
        return cell
    }
    
    /**
    * When the user taps a row in the table, display the USGS web page that displays details of the earthquake they selected.
    */
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        
        let buttonTitle = NSLocalizedString("Cancel", comment: "Cancel")
        let buttonTitle1 = NSLocalizedString("Show USGS Site in Safari", comment: "Show USGS Site in Safari")
        let buttonTitle2 = NSLocalizedString("Show Location in Maps", comment: "Show Location in Maps")
        if NSClassFromString("UIAlertController") != nil {
            let alert = UIAlertController(title: nil, message: nil, preferredStyle: .ActionSheet)
            alert.addAction(UIAlertAction(title: buttonTitle1, style: .Default, handler: {action in
                self.actionSheet(UIActionSheet(), willDismissWithButtonIndex: 0)
            }))
            alert.addAction(UIAlertAction(title: buttonTitle2, style: .Default, handler: {action in
                self.actionSheet(UIActionSheet(), willDismissWithButtonIndex: 1)
            }))
            alert.addAction(UIAlertAction(title: buttonTitle, style: .Cancel, handler: {action in
                self.actionSheet(UIActionSheet(), willDismissWithButtonIndex: 2)
            }))
            self.presentViewController(alert, animated: true, completion: {})
        } else {
            let sheet = UIActionSheet()
            sheet.delegate = self
            sheet.addButtonWithTitle(buttonTitle1)
            sheet.addButtonWithTitle(buttonTitle2)
            sheet.addButtonWithTitle(buttonTitle)
            sheet.cancelButtonIndex = 2
            sheet.showInView(self.view)
        }
    }
    
    
    //MARK: -
    
    /**
    * Called when the user selects an option in the sheet. The sheet will automatically be dismissed.
    */
    func actionSheet(actionSheet: UIActionSheet, willDismissWithButtonIndex buttonIndex: Int) {
        
        let selectedIndexPath = self.tableView.indexPathForSelectedRow()!
        let earthquake = self.earthquakeList[selectedIndexPath.row]
        
        switch buttonIndex {
        case 0:
            // open the earthquake info in Safari
            //
            UIApplication.sharedApplication().openURL(earthquake.USGSWebLink)
        case 1:
            // open the earthquake info in Maps
            
            // create a map region pointing to the earthquake location
            let location = CLLocationCoordinate2D(latitude: earthquake.latitude, longitude: earthquake.longitude)
            let locationValue = NSValue(MKCoordinate: location)
            
            let span = MKCoordinateSpan(latitudeDelta: 2.0, longitudeDelta: 2.0)
            let spanValue = NSValue(MKCoordinateSpan: span)
            
            let launchOptions: NSDictionary = [MKLaunchOptionsMapTypeKey : MKMapType.Standard.rawValue,
                MKLaunchOptionsMapCenterKey : locationValue,
                MKLaunchOptionsMapSpanKey : spanValue,
                MKLaunchOptionsShowsTrafficKey : false,
                MKLaunchOptionsDirectionsModeDriving : false]
            
            // make sure the map item has a pin placed on it with the title as the earthquake location
            let placemark = MKPlacemark(coordinate: location, addressDictionary: nil)
            let mapItem = MKMapItem(placemark: placemark)
            mapItem.name = earthquake.location
            mapItem.openInMapsWithLaunchOptions(launchOptions)
            
        default:
            break
        }
        
        self.tableView.deselectRowAtIndexPath(selectedIndexPath, animated: true)
    }
    
    
    //MARK: - Locale changes
    
    func localeChanged(notif: NSNotificationCenter) {
        // the user changed the locale (region format) in Settings, so we are notified here to
        // update the date format in the table view cells
        //
        self.tableView.reloadData()
    }
    
}