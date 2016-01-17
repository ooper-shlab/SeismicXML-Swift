//
//  APLViewController.swift
//  SeismicXML
//
//  Translated by OOPer in cooperation with shlab.jp, on 2014/09/13.
//
//

/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information

 Abstract:
 View controller for displaying the earthquake list.
 */

import UIKit
// this framework is imported so we can use the kCFURLErrorNotConnectedToInternet error code
import CFNetwork
import MapKit   // for CLLocationCoordinate2D and MKPlacemark

@objc(APLViewController)
class ViewController: UITableViewController {
    
    private var earthQuakeSource: APLEarthQuakeSource!
    
    private var localChangedObserver: AnyObject!
    
    
    //MARK: -
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        earthQuakeSource = APLEarthQuakeSource()
        
        // listen for incoming earthquakes from our data source using KVO
        self.earthQuakeSource.addObserver(self,  forKeyPath: "earthquakes", options: [], context: nil)
        
        // listen for errors reported by our data source using KVO, so we can report it in our own way
        self.earthQuakeSource.addObserver(self, forKeyPath: "error", options: .New, context: nil)
        
        // Our NSNotification callback when the user changes the locale (region format) in Settings, so we are notified here to
        // update the date format in the table view cells
        //
        localChangedObserver =
            NSNotificationCenter.defaultCenter().addObserverForName(NSCurrentLocaleDidChangeNotification,
                object: nil,
                queue: nil) {notification in
                    self.tableView.reloadData()
        }
    }
    
    override func viewDidAppear(animated: Bool) {
        
        super.viewDidAppear(animated)
        
        UIApplication.sharedApplication().networkActivityIndicatorVisible = false
        self.earthQuakeSource.startEarthQuakeLookup()
    }
    
    deinit {
        
        NSNotificationCenter.defaultCenter().removeObserver(self.localChangedObserver)
    }
    
    
    //MARK: - UITableViewDelegate
    
    /**
    * The number of rows is equal to the number of earthquakes in the array.
    */
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        return self.earthQuakeSource.earthquakes.count
    }
    
    /**
     * Return the proper table view cell for each earthquake
     */
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        
        let kEarthquakeCellID = "EarthquakeCellID"
        let cell = tableView.dequeueReusableCellWithIdentifier(kEarthquakeCellID) as! EarthquakeTableViewCell
        
        // Get the specific earthquake for this row.
        let earthquake = self.earthQuakeSource.earthquakes[indexPath.row]
        
        cell.configureWithEarthquake(earthquake)
        
        return cell
    }
    
    /**
     * When the user taps a row in the table, display the USGS web page that displays details of the earthquake they selected.
     */
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        
        // open the earthquake info in Maps, note this will not work in the simulator
        let selectedIndexPath = self.tableView.indexPathForSelectedRow!
        let earthquake = self.earthQuakeSource.earthquakes[selectedIndexPath.row]
        
        // create a map region pointing to the earthquake location
        let location = CLLocationCoordinate2D(latitude: earthquake.latitude, longitude: earthquake.longitude)
        let locationValue = NSValue(MKCoordinate: location)
        
        let span = MKCoordinateSpan(latitudeDelta: 50, longitudeDelta: 50)
        let spanValue = NSValue(MKCoordinateSpan: span)
        
        let launchOptions: [String: AnyObject] = [MKLaunchOptionsMapTypeKey : MKMapType.Standard.rawValue,
            MKLaunchOptionsMapCenterKey : locationValue,
            MKLaunchOptionsMapSpanKey : spanValue,
            MKLaunchOptionsShowsTrafficKey : false,
            MKLaunchOptionsDirectionsModeDriving : false ]
        
        // make sure the map item has a pin placed on it with the title as the earthquake location
        let placemark = MKPlacemark(coordinate: location,
            addressDictionary: nil)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = earthquake.location
        mapItem.openInMapsWithLaunchOptions(launchOptions)
        
        self.tableView.deselectRowAtIndexPath(indexPath, animated: true)
    }
    
    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        let earthQuakeSource = object as! APLEarthQuakeSource
        
        switch keyPath {
        case "earthquakes"?:
            dispatch_async(dispatch_get_main_queue()) {
                
                UIApplication.sharedApplication().networkActivityIndicatorVisible = false
                self.tableView.reloadData()
            }
        case "error"?:
            /* Handle errors in the download by showing an alert to the user. This is a very simple way of handling the error, partly because this application does not have any offline functionality for the user. Most real applications should handle the error in a less obtrusive way and provide offline functionality to the user.
            */
            dispatch_async(dispatch_get_main_queue()) {
                UIApplication.sharedApplication().networkActivityIndicatorVisible = false
                
                let error = earthQuakeSource.error
                
                let errorMessage = error!.localizedDescription
                let alertTitle = NSLocalizedString("Error", comment: "Title for alert displayed when download or parse error occurs.")
                let okTitle = NSLocalizedString("OK", comment: "OK Title for alert displayed when download or parse error occurs.")
                
                if #available(iOS 8.0, *) {
                    let alert = UIAlertController(title: alertTitle, message: errorMessage, preferredStyle: .Alert)
                    
                    let action = UIAlertAction(title: okTitle, style: .Default) {act in
                        //..
                    }
                    alert.addAction(action)
                    
                    if self.presentedViewController == nil {
                        self.presentViewController(alert, animated: true) {
                            //..
                        }
                    }
                } else {
                    let alertView = UIAlertView(title: alertTitle, message: errorMessage, delegate: self, cancelButtonTitle: okTitle)
                    alertView.show()
                    //..
                }
            }
        default:
            super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
        }
    }
    
}

extension ViewController: UIAlertViewDelegate {
    
    //### Handle OK here in iOS 7.x
    func alertView(alertView: UIAlertView, clickedButtonAtIndex buttonIndex: Int) {
        //..
    }
}