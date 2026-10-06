//
//  LocationService.swift
//  ArtNote
//
//  Created by Honoka Nishiyama on 2025/10/27.
//

import CoreLocation
import Observation

@MainActor
@Observable
final class LocationManager: NSObject, @preconcurrency CLLocationManagerDelegate {
    var authorization: CLAuthorizationStatus = .notDetermined
    var location: CLLocation?

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 50
    }

    func request() {
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    func locationManagerDidChangeAuthorization(_ m: CLLocationManager) {
        authorization = m.authorizationStatus
        if authorization == .authorizedWhenInUse || authorization == .authorizedAlways { m.startUpdatingLocation() }
    }
    func locationManager(_ m: CLLocationManager, didUpdateLocations locs: [CLLocation]) {
        if let last = locs.last { location = last }
    }
}
