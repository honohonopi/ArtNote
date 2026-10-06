//
//  HomeView.swift
//  ArtNote
//
//  Created by Honoka Nishiyama on 2025/10/03.
//

import SwiftUI
import SwiftData
import CoreLocation

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    
    @AppStorage("soonDays") private var soonDays: Int = 7
    @ObservedObject private var settingsStore = SettingsStore.shared
    
    @Query(sort: [SortDescriptor(\Exhibition.endDate, order: .forward)])
    private var allExhibitions: [Exhibition]
    
    @State private var vm = HomeViewModel()

    @StateObject private var loc = LocationManager()
    
    @State private var showSettings = false

    private var hereKeyString: String {
        guard let c = loc.location?.coordinate else { return "nil" }
        return String(format: "%.5f,%.5f", c.latitude, c.longitude)
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                List {
                    HomeSoonSectionView(soonDays: $soonDays, exhibitions: vm.soonExhibitions(from: allExhibitions, within: soonDays))

                    HomeNearbySectionView(
                        nearbyRadiusKm: $settingsStore.nearbyRadiusKm,
                        location: loc.location,
                        authorization: loc.authorization,
                        items: vm.nearbyExhibitions,
                        requestLocation: { loc.request() },
                        onSelectExhibition: { id in
                            // 選択表示の更新後に、リスト全体をスクロールする。
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                withAnimation(.easeInOut) {
                                    proxy.scrollTo("nearby-\(id)", anchor: .center)
                                }
                            }
                        }
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
                .onChange(of: settingsStore.nearbyRadiusKm) {
                    recomputeNearby()
                }
                .onAppear {
                    if loc.authorization == .notDetermined { loc.request() }
                    recomputeNearby()
                    checkNearbyOpenNotification()
                }
                .onChange(of: hereKeyString) { _ in
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
                .sheet(isPresented: $showSettings) {
                    SettingsView()
                }
            }
        }
    }

    private func recomputeNearby() {
        vm.recomputeNearby(
            exhibitions: allExhibitions,
            coordinate: loc.location?.coordinate
        )
    }

    private func checkNearbyOpenNotification() {
        vm.checkNearbyOpenNotification(coordinate: loc.location?.coordinate)
    }
}
