//
//  LocationSearchViewModel.swift
//  ArtNote
//
//  Created by Honoka Nishiyama on 2025/10/27.
//

import Foundation
import MapKit

@MainActor
final class LocationSearchViewModel: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var query: String = ""
    @Published var suggestions: [MKLocalSearchCompletion] = []

    private let completer = MKLocalSearchCompleter()
    private var region: MKCoordinateRegion?

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.pointOfInterest, .address]
    }

    func updateBiasRegion(_ region: MKCoordinateRegion) {
        self.region = region
        completer.region = region
    }

    func onQueryChange(_ text: String) {
        completer.queryFragment = text
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        self.suggestions = completer.results
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        self.suggestions = []
    }

    /// 候補を選択→検索→座標を返す
    func resolve(_ completion: MKLocalSearchCompletion) async -> CLLocationCoordinate2D? {
        let request = MKLocalSearch.Request(completion: completion)
        if let region { request.region = region } // 近場を優先
        let search = MKLocalSearch(request: request)
        do {
            let resp = try await search.start()
            return resp.mapItems.first?.placemark.coordinate
        } catch {
            return nil
        }
    }

    /// 生テキストで検索（Returnキー用）
    func resolveRawQuery() async -> CLLocationCoordinate2D? {
        guard !query.isEmpty else { return nil }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        if let region { request.region = region }
        do {
            let resp = try await MKLocalSearch(request: request).start()
            return resp.mapItems.first?.placemark.coordinate
        } catch {
            return nil
        }
    }
}
