//
//  APLEarthquake.swift
//  SeismicXML
//
//  Translated by OOPer in cooperation with shlab.jp, on 2016/01/12.
//
//
/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information

 Abstract:
 The model class that stores the information about an earthquake.
 */

import Foundation

@objc(APLEarthquake)
class Earthquake: NSObject {
    
    // Magnitude of the earthquake on the Richter scale.
    var magnitude: Float = 0.0
    // Name of the location of the earthquake.
    var location: String = ""
    // Date and time at which the earthquake occurred.
    var date: Date!
    // Latitude and longitude of the earthquake.
    var latitude: Double = 0.0
    var longitude: Double = 0.0
    
}
