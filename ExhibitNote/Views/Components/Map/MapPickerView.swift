//
//  MapPickerView.swift
//  ArtNote
//
//  Created by Honoka Nishiyama on 2025/10/27.
//

import SwiftUI
import MapKit

struct MapPickerView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var cameraPosition: MapCameraPosition
    @State private var region: MKCoordinateRegion
    @State private var centerCoord: CLLocationCoordinate2D
    @State private var searchVM = LocationSearchViewModel()

    let onSelect: (CLLocationCoordinate2D, String?) -> Void

    init(seed: CLLocationCoordinate2D?, onSelect: @escaping (CLLocationCoordinate2D, String?) -> Void) {
        let center = seed ?? CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671)
        let initialRegion = MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        )
        _centerCoord = State(initialValue: center)
        _region = State(initialValue: initialRegion)
        _cameraPosition = State(initialValue: .region(initialRegion))
        self.onSelect = onSelect
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Map(position: $cameraPosition, interactionModes: [.pan, .zoom])
                    .ignoresSafeArea(edges: .bottom)
                    .onMapCameraChange(frequency: .onEnd) { context in
                        region = context.region
                        centerCoord = context.region.center
                        searchVM.updateBiasRegion(context.region)
                    }
                
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.red)
                    .shadow(radius: 2)
                    .allowsHitTesting(false)
            }
            .task {
                searchVM.updateBiasRegion(region)
            }
            .overlay(alignment: .bottom) {
                Button {
                    Task {
                        // 逆ジオコーディングして住所を推定
                        let addr = await reverseGeocode(centerCoord)
                        onSelect(centerCoord, addr)
                        dismiss()
                    }
                } label: {
                    Text("この位置に決定")
                        .bold()
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding()
                }
            }
            .navigationTitle("会場の位置を選択")
            .navigationBarTitleDisplayMode(.inline)
            
            // 検索バー
            .searchable(text: $searchVM.query, placement: .navigationBarDrawer, prompt: "場所や施設名を検索")
            .onChange(of: searchVM.query) { _, query in
                searchVM.onQueryChange(query)
            }
            
            // 候補サジェスト
            .searchSuggestions {
                ForEach(searchVM.suggestions, id: \.self) { item in
                    Button {
                        Task {
                            if let coord = await searchVM.resolve(item) {
                                // 見つけた場所へ地図を移動
                                let newRegion = MKCoordinateRegion(
                                    center: coord,
                                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                                )
                                region = newRegion
                                centerCoord = coord
                                cameraPosition = .region(newRegion)
                                searchVM.query = ""   // 入力クリア（任意）
                            }
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title).bold()
                            Text(item.subtitle).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            // Enterキーで検索
            .onSubmit(of: .search) {
                Task {
                    if let coord = await searchVM.resolveRawQuery() {
                        let newRegion = MKCoordinateRegion(
                            center: coord,
                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        )
                        region = newRegion
                        centerCoord = coord
                        cameraPosition = .region(newRegion)
                        searchVM.query = ""
                    }
                }
            }
        }
    }
    
    private func reverseGeocode(_ coord: CLLocationCoordinate2D) async -> String? {
        let geocoder = CLGeocoder()
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(
                CLLocation(latitude: coord.latitude, longitude: coord.longitude),
                preferredLocale: Locale(identifier: "ja_JP")
            )
            guard let p = placemarks.first else { return nil }
            // 簡易フォーマット（必要に応じて調整）
            let parts: [String] = [
                p.administrativeArea,   // 都道府県
                p.locality,             // 市区町村
                p.subLocality,          // 町域
                p.thoroughfare,         // 通り
                p.subThoroughfare,      // 番地
                p.name                  // 施設名など
            ].compactMap { $0 }.filter { !$0.isEmpty }
            return parts.joined()
        } catch {
            return nil
        }
    }
}
