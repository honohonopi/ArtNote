//
//  HomeView.swift
//  ArtNote
//
//  Created by Honoka Nishiyama on 2025/10/03.
//

import SwiftUI
import SwiftData
import CoreLocation
import MapKit

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    
    @AppStorage("soonDays") private var soonDays: Int = 7
    @AppStorage("nearbyRadiusKm") private var nearbyRadiusKm: Double = 10
    @ObservedObject private var settingsStore = SettingsStore.shared
    
    @Query(sort: [SortDescriptor(\Exhibition.endDate, order: .forward)])
    private var allExhibitions: [Exhibition]
    
    @StateObject private var vm = HomeViewModel()

    @StateObject private var loc = LocationManager()
    
    @State private var isAdjustingRadius = false
    
    @State private var selectedPinID: String? = nil
    @State private var highlightedExID: String? = nil
    @State private var showSettings = false
    
    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671),
        span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
    )
    
    private var nearbyDisplayLimit: Int { 5 }
    
    private var nearbyPins: [MapPin] {
        var pins: [MapPin] = []
        if let here = loc.location?.coordinate {
            pins.append(.init(id: "here", coordinate: here, title: "現在地", isHere: true, exhibition: nil))
        }
        for (ex, _) in vm.nearbyExhibitions.prefix(nearbyDisplayLimit) {
            if let c = ex.coordinate {
                pins.append(.init(id: ex.id, coordinate: c, title: ex.title, isHere: false, exhibition: ex)) // ← ここで紐付け
            }
        }
        return pins
    }
    
    private var spanForRadius: MKCoordinateSpan {
        let deg = max(nearbyRadiusKm / 111.0, 0.02)
        return MKCoordinateSpan(latitudeDelta: deg, longitudeDelta: deg)
    }
    
    private var hereKeyString: String {
        guard let c = loc.location?.coordinate else { return "nil" }
        return String(format: "%.5f,%.5f", c.latitude, c.longitude)
    }

    private func exhibitionID(for pinID: String?) -> String? {
        guard let pinID,
              let pin = nearbyPins.first(where: { $0.id == pinID }),
              let ex = pin.exhibition
        else { return nil }
        return ex.id
    }

    private func nearbyScrollID(for exhibitionID: String) -> String {
        "nearby-\(exhibitionID)"
    }
    
    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                List {
                HomeSoonSectionView(soonDays: $soonDays, exhibitions: vm.soonExhibitions(from: allExhibitions, within: soonDays))
                
                HomeNearbySectionView(
                    nearbyRadiusKm: $nearbyRadiusKm,
                    mapRegion: $mapRegion,
                    authorization: loc.authorization,
                    items: vm.nearbyExhibitions,
                    displayLimit: nearbyDisplayLimit,
                    pins: nearbyPins,
                    requestLocation: { loc.request() },
                    onRadiusEditingChanged: { isEditing in
                        isAdjustingRadius = isEditing
                        // 指を離したタイミングでだけ地図更新＆再計算
                        if !isEditing {
                            mapRegion.span = spanForRadius
                            recomputeNearby()
                        }
                    },
                    selectedPinID: $selectedPinID,
                    highlightedExID: $highlightedExID
                )
                }
                .navigationTitle("ホーム")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                        }
                    }
                }
                .task {
                    await vm.requestNotificationAuthorization(in: context)
                    recomputeNearby()
                    checkNearbyOpenNotification()
                }
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active else { return }
                    recomputeNearby()
                    checkNearbyOpenNotification()
                }
                // 近接半径が変わっても、ドラッグ中は重い更新をしない
                .onChange(of: nearbyRadiusKm) { _ in
                    guard !isAdjustingRadius else { return }
                    mapRegion.span = spanForRadius
                    recomputeNearby()
                }
                .onAppear {
                    if loc.authorization == .notDetermined { loc.request() }
                    recomputeNearby()
                    checkNearbyOpenNotification()
                }
                .onChange(of: hereKeyString) { _ in
                    if let c = loc.location?.coordinate {
                        mapRegion.center = c
                        mapRegion.span = spanForRadius
                    }
                    recomputeNearby()
                    checkNearbyOpenNotification()
                }
                // 件数だけ監視にして型推論を軽く
                .onChange(of: allExhibitions.count) { _ in
                    recomputeNearby()
                    checkNearbyOpenNotification()
                }
                .onChange(of: settingsStore.notifyNearbyOpenEnabled) { _, _ in
                    checkNearbyOpenNotification()
                }
                .onChange(of: settingsStore.notifyNearbyRadiusKm) { _, _ in
                    checkNearbyOpenNotification()
                }
                .onChange(of: selectedPinID) { _, newValue in
                    let target = exhibitionID(for: newValue)
                    highlightedExID = target
                    guard let target else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        withAnimation(.easeInOut) {
                            proxy.scrollTo(nearbyScrollID(for: target), anchor: .center)
                        }
                    }
                }
                .sheet(isPresented: $showSettings) {
                    SettingsView()
                }
            }
        }
    }

    private func recomputeNearby() {
        vm.recomputeNearby(
            exhibitions: allExhibitions,
            coordinate: loc.location?.coordinate,
            radiusKm: nearbyRadiusKm
        )
    }

    private func checkNearbyOpenNotification() {
        vm.checkNearbyOpenNotification(
            isEnabled: settingsStore.notifyNearbyOpenEnabled,
            coordinate: loc.location?.coordinate,
            radiusKm: settingsStore.notifyNearbyRadiusKm
        )
    }
}
