//
//  VenueGeocodingService.swift
//  ArtNote
//
//  Created by Honoka Nishiyama on 2025/10/27.
//

import Foundation
import CoreLocation
import MapKit

enum VenueGeocodingService {
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
        guard !key.isEmpty, let result = try await searchWithMapKit(query: key) else { return nil }
        resultCache[key] = result
        cache[key] = result.coordinate
        return result.coordinate
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

            // ② 施設以外も含めて検索
            if let result = try? await searchWithMapKit(query: q) {
                resultCache[q] = result
                cache[q] = result.coordinate
                return (result.coordinate, result.address)
            }
        }

        print("📍 geocodeWithAddress failed for all queries")
        return nil
    }


    private static func formattedAddress(from item: MKMapItem) -> String? {
        item.addressRepresentations?.fullAddress(includingRegion: false, singleLine: true)
            ?? item.address?.fullAddress
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
        let address = formattedAddress(from: item)
        print("📍 MKLocalSearch addr: \"\(address ?? "nil")\"")
        return GeocodeResult(coordinate: item.location.coordinate, address: address)
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

        let address = formattedAddress(from: item)

        print("📍 POI hit: \"\(item.name ?? "-")\"")

        return GeocodeResult(
            coordinate: item.location.coordinate,
            address: address
        )
    }
}
