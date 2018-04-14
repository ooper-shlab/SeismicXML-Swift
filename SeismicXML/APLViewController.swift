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
        self.earthQuakeSource.addObserver(self, forKeyPath: "error", options: .new, context: nil)
        
        // Our NSNotification callback when the user changes the locale (region format) in Settings, so we are notified here to
        // update the date format in the table view cells
        //
        localChangedObserver =
            NotificationCenter.default.addObserver(forName: NSLocale.currentLocaleDidChangeNotification,
                object: nil,
                queue: nil) {notification in
                    self.tableView.reloadData()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
        super.viewDidAppear(animated)
        
        UIApplication.shared.isNetworkActivityIndicatorVisible = false
        self.earthQuakeSource.startEarthQuakeLookup()
    }
    
    deinit {
        
        NotificationCenter.default.removeObserver(self.localChangedObserver)
    }
    
    
    //MARK: - UITableViewDelegate
    
    /**
    * The number of rows is equal to the number of earthquakes in the array.
    */
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        return self.earthQuakeSource.earthquakes.count
    }
    
    /**
     * Return the proper table view cell for each earthquake
     */
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let kEarthquakeCellID = "EarthquakeCellID"
        let cell = tableView.dequeueReusableCell(withIdentifier: kEarthquakeCellID) as! EarthquakeTableViewCell
        
        // Get the specific earthquake for this row.
        let earthquake = self.earthQuakeSource.earthquakes[indexPath.row]
        
        cell.configureWithEarthquake(earthquake)
        
        return cell
    }
    
    /**
     * When the user taps a row in the table, display the USGS web page that displays details of the earthquake they selected.
     */
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        // open the earthquake info in Maps, note this will not work in the simulator
        let selectedIndexPath = self.tableView.indexPathForSelectedRow!
        let earthquake = self.earthQuakeSource.earthquakes[selectedIndexPath.row]
        
        // create a map region pointing to the earthquake location
        let location = CLLocationCoordinate2D(latitude: earthquake.latitude, longitude: earthquake.longitude)
        
        let span = MKCoordinateSpan(latitudeDelta: 50, longitudeDelta: 50)
        
        let launchOptions: [String: Any] = [MKLaunchOptionsMapTypeKey : MKMapType.standard.rawValue,
            MKLaunchOptionsMapCenterKey : location,
            MKLaunchOptionsMapSpanKey : span,
            MKLaunchOptionsShowsTrafficKey : false,
            MKLaunchOptionsDirectionsModeDriving : false]
        
        // make sure the map item has a pin placed on it with the title as the earthquake location
        let placemark = MKPlacemark(coordinate: location,
            addressDictionary: nil)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = earthquake.location
        mapItem.openInMaps(launchOptions: launchOptions)
        
        self.tableView.deselectRow(at: indexPath, animated: true)
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        let earthQuakeSource = object as! APLEarthQuakeSource
        
        switch keyPath {
        case "earthquakes"?:
            DispatchQueue.main.async {
                
                UIApplication.shared.isNetworkActivityIndicatorVisible = false
                self.tableView.reloadData()
            }
        case "error"?:
            /* Handle errors in the download by showing an alert to the user. This is a very simple way of handling the error, partly because this application does not have any offline functionality for the user. Most real applications should handle the error in a less obtrusive way and provide offline functionality to the user.
            */
            DispatchQueue.main.async {
                UIApplication.shared.isNetworkActivityIndicatorVisible = false
                
                let error = earthQuakeSource.error
                
                let errorMessage = error!.localizedDescription
                let alertTitle = NSLocalizedString("Error", comment: "Title for alert displayed when download or parse error occurs.")
                let okTitle = NSLocalizedString("OK", comment: "OK Title for alert displayed when download or parse error occurs.")
                
                let alert = UIAlertController(title: alertTitle, message: errorMessage, preferredStyle: .alert)
                
                let action = UIAlertAction(title: okTitle, style: .default) {act in
                    //..
                }
                alert.addAction(action)
                
                if self.presentedViewController == nil {
                    self.present(alert, animated: true) {
                        //..
                    }
                }
            }
        default:
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
    
}

extension ViewController: UIAlertViewDelegate {
    
    //### Handle OK here in iOS 7.x
    func alertView(_ alertView: UIAlertView, clickedButtonAt buttonIndex: Int) {
        //..
    }
}
