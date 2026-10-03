//
//  Exhibition+Location.swift
//  ExhibitNote
//
//  Created by Honoka Nishiyama on 2026/01/06.
//

import Foundation
import CoreLocation

extension Exhibition {
    var hasCoordinate: Bool { latitude != nil && longitude != nil }
    
    var coordinate: CLLocationCoordinate2D? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
    
    func setCoordinate(_ c: CLLocationCoordinate2D) {
        latitude = c.latitude; longitude = c.longitude
    }
}
