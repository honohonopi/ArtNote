//
//  VenueGeocodingService.swift.swift
//  ArtNote
//
//  Created by Honoka Nishiyama on 2025/10/27.
//

import Foundation
import CoreLocation

enum VenueGeocodingService {
    private static let geocoder = CLGeocoder()
    private static var cache: [String: CLLocationCoordinate2D] = [:]

    static func geocode(_ venue: String) async throws -> CLLocationCoordinate2D? {
        let key = venue.trimmingCharacters(in: .whitespacesAndNewlines)
        if let cached = cache[key] { return cached }
        guard !geocoder.isGeocoding else { try await Task.sleep(nanoseconds: 200_000_000) ; return try await geocode(venue) }

        let placemarks = try await geocoder.geocodeAddressString(key, in: nil, preferredLocale: Locale(identifier: "ja_JP"))
        guard let loc = placemarks.first?.location?.coordinate else { return nil }
        cache[key] = loc
        return loc
    }
}
