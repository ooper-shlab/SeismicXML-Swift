//
//  APLEarthquakeTableViewCell.swift
//  SeismicXML
//
//  Translated by OOPer in cooperation with shlab.jp, on 2014/09/13.
//
//

/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information

 Abstract:
 Table view cell to display an earthquake.
 */

import UIKit

@objc(APLEarthquakeTableViewCell)
class EarthquakeTableViewCell: UITableViewCell {
    
    // References to the subviews which display the earthquake data.
    @IBOutlet weak var locationLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var magnitudeLabel: UILabel!
    @IBOutlet weak var magnitudeImage: UIImageView!
    
    
    func configureWithEarthquake(_ earthquake: Earthquake) {
        
        self.locationLabel.text = earthquake.location
        self.dateLabel.text = self.dateFormatter.string(from: earthquake.date as Date)
        self.magnitudeLabel.text = String(format: "%.1f", Double(earthquake.magnitude))
        self.magnitudeImage.image = self.imageForMagnitude(earthquake.magnitude)
    }
    
    
    // Based on the magnitude of the earthquake, return an image indicating its seismic strength.
    private func imageForMagnitude(_ magnitude: Float) -> UIImage? {
        
        if magnitude >= 5.0 {
            return UIImage(named: "5.0.png")
        }
        if magnitude >= 4.0 {
            return UIImage(named: "4.0.png")
        }
        if magnitude >= 3.0 {
            return UIImage(named: "3.0.png")
        }
        if magnitude >= 0.0 {
            return UIImage(named: "2.0.png")
        }
        return nil
    }
    
    
    // On-demand initializer for read-only property.
    private lazy var dateFormatter: DateFormatter = {
        
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone.autoupdatingCurrent
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .medium
        return dateFormatter
    }()
    
    
}
