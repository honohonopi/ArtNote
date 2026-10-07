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
                        let address = await searchVM.address(for: centerCoord)
                        onSelect(centerCoord, address)
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
                            if let coordinate = await searchVM.resolve(item) {
                                updateMapPosition(to: coordinate)
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
                    if let coordinate = await searchVM.resolveRawQuery() {
                        updateMapPosition(to: coordinate)
                    }
                }
            }
        }
    }

    private func updateMapPosition(to coordinate: CLLocationCoordinate2D) {
        let newRegion = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        region = newRegion
        centerCoord = coordinate
        cameraPosition = .region(newRegion)
        searchVM.query = ""
    }
}
