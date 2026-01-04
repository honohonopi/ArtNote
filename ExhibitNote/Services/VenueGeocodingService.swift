//
//  VenueGeocodingService.swift.swift
//  ArtNote
//
//  Created by Honoka Nishiyama on 2025/10/27.
//

import Foundation
import CoreLocation
import MapKit

enum VenueGeocodingService {
    private static let geocoder = CLGeocoder()
    private static var cache: [String: CLLocationCoordinate2D] = [:]
    private struct GeocodeResult {
        let coordinate: CLLocationCoordinate2D
        let address: String?
    }
    private static var resultCache: [String: GeocodeResult] = [:]

    static func geocode(_ venue: String) async throws -> CLLocationCoordinate2D? {
        let key = venue.trimmingCharacters(in: .whitespacesAndNewlines)
        if let cached = resultCache[key]?.coordinate { return cached }
        if let cached = cache[key] { return cached }
        guard !geocoder.isGeocoding else { try await Task.sleep(nanoseconds: 200_000_000) ; return try await geocode(venue) }

        let placemarks = try await geocoder.geocodeAddressString(key, in: nil, preferredLocale: Locale(identifier: "ja_JP"))
        guard let loc = placemarks.first?.location?.coordinate else { return nil }
        cache[key] = loc
        return loc
    }

    static func geocodeWithAddress(_ venue: String) async throws
    -> (coordinate: CLLocationCoordinate2D, address: String?)? {

        let normalizedQueries = normalizeVenueQuery(venue)

        for q in normalizedQueries {
            // ① POI 検索を最優先
            if let poi = try? await searchPOI(query: q) {
                resultCache[q] = poi
                cache[q] = poi.coordinate
                return (poi.coordinate, poi.address)
            }

            // ② 住所検索（フォールバック）
            if let placemark = try? await geocoder
                .geocodeAddressString(q, in: nil, preferredLocale: Locale(identifier: "ja_JP"))
                .first,
               let loc = placemark.location?.coordinate {

                let addr = formattedAddress(from: placemark)
                let result = GeocodeResult(coordinate: loc, address: addr)
                resultCache[q] = result
                cache[q] = loc
                return (loc, addr)
            }
        }

        print("📍 geocodeWithAddress failed for all queries")
        return nil
    }


    private static func formattedAddress(from placemark: CLPlacemark) -> String? {
        let parts: [String] = [
            placemark.administrativeArea,
            placemark.locality,
            placemark.subLocality,
            placemark.thoroughfare,
            placemark.subThoroughfare,
            placemark.name
        ]
        .compactMap { $0 }
        .filter { !$0.isEmpty }
        let joined = parts.joined()
        return joined.isEmpty ? nil : joined
    }

    private static func searchWithMapKit(query: String) async throws -> GeocodeResult? {
        print("📍 MKLocalSearch query: \"\(query)\"")
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        let response = try await MKLocalSearch(request: request).start()
        guard let item = response.mapItems.first else {
            print("📍 MKLocalSearch no mapItems")
            return nil
        }
        let placemark = item.placemark
        let addr = formattedAddress(from: placemark)
        print("📍 MKLocalSearch addr: \"\(addr ?? "nil")\"")
        return GeocodeResult(coordinate: placemark.coordinate, address: addr)
    }
    
    private static func normalizeVenueQuery(_ venue: String) -> [String] {
        let base = venue.trimmingCharacters(in: .whitespacesAndNewlines)

        var queries: [String] = [base]

        // ギャラリー・館内施設を落とす
        let stripped = base
            .replacingOccurrences(of: "P&Pギャラリー", with: "")
            .replacingOccurrences(of: "ギャラリー", with: "")
            .replacingOccurrences(of: "展示室", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if stripped != base {
            queries.append(stripped)
        }

        return Array(Set(queries))   // 重複除去
    }

    private static func searchPOI(query: String) async throws -> GeocodeResult? {
        print("📍 POI search query: \"\(query)\"")

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = .pointOfInterest   // ★ ここが肝

        let response = try await MKLocalSearch(request: request).start()
        guard let item = response.mapItems.first else {
            print("📍 POI search no results")
            return nil
        }

        let placemark = item.placemark
        let address = formattedAddress(from: placemark)

        print("📍 POI hit: \"\(item.name ?? "-")\"")

        return GeocodeResult(
            coordinate: placemark.coordinate,
            address: address
        )
    }
}
