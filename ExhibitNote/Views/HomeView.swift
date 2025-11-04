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

struct ExhibitionRowView: View {
    let ex: Exhibition
    let distanceKm: Double?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(ex.title).font(.headline)
            Text("\(ex.venue)｜〜 \(ex.endDate.ymdString)")
                .font(.subheadline).foregroundStyle(.secondary)
            if let km = distanceKm {
                Text(String(format: "約 %.1f km", km))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

struct MapPin: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let title: String
    let isHere: Bool
}

struct NearbyMiniMapView: View {
    @Binding var region: MKCoordinateRegion
    let pins: [MapPin]
    
    var body: some View {
        Map(
            coordinateRegion: $region,
            interactionModes: [.zoom, .pan],
            showsUserLocation: false,
            annotationItems: pins
        ) { (pin: MapPin) in
            pin.isHere
            ? MapMarker(coordinate: pin.coordinate, tint: .blue)
            : MapMarker(coordinate: pin.coordinate, tint: .red)
        }
    }
}

struct HomeSoonSectionView: View {
    let soonDays: Int
    let exhibitions: [Exhibition]
    
    var body: some View {
        Section(header: Text("まもなく終了（\(soonDays)日以内）")) {
            if exhibitions.isEmpty {
                ContentUnavailableView("該当する展示はありません", systemImage: "checkmark.seal")
            } else {
                ForEach(Array(exhibitions.prefix(5))) { ex in
                    NavigationLink(value: ex) {
                        ExhibitionRowView(ex: ex, distanceKm: nil)
                    }
                }
            }
        }
    }
}

struct HomeNearbySectionView: View {
    @Binding var nearbyRadiusKm: Double
    @Binding var mapRegion: MKCoordinateRegion
    
    let authorization: CLAuthorizationStatus
    let items: [(Exhibition, Double)]   // 距離付き（近い順）
    let pins: [MapPin]
    let requestLocation: () -> Void
    
    var body: some View {
        Section(header: Text("近くで開催中（\(Int(nearbyRadiusKm)) km以内）")) {
            HStack {
                Image(systemName: "figure.walk.circle")
                Text("半径 \(Int(nearbyRadiusKm)) km")
                Slider(value: $nearbyRadiusKm, in: 3...50, step: 1)
            }
            .padding(.vertical, 4)
            
            if (authorization == .authorizedAlways || authorization == .authorizedWhenInUse),
               !pins.isEmpty {
                NearbyMiniMapView(region: $mapRegion, pins: pins)
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            switch authorization {
            case .authorizedAlways, .authorizedWhenInUse:
                if items.isEmpty {
                    ContentUnavailableView("近くで開催中の展示はありません", systemImage: "mappin.and.ellipse")
                } else {
                    ForEach(Array(items.prefix(5)), id: \.0.id) { ex, km in
                        NavigationLink(value: ex) {
                            ExhibitionRowView(ex: ex, distanceKm: km)
                        }
                    }
                }
            case .notDetermined:
                Button(action: requestLocation) {
                    Label("近くの展示を表示するには位置情報を許可", systemImage: "location")
                }
            default:
                ContentUnavailableView("位置情報の許可が必要です", systemImage: "location.slash")
            }
        }
    }
}

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    
    @AppStorage("soonDays") private var soonDays: Int = 7
    @AppStorage("nearbyRadiusKm") private var nearbyRadiusKm: Double = 10
    
    @Query(sort: [SortDescriptor(\Exhibition.endDate, order: .forward)])
    private var allExhibitions: [Exhibition]
    
    @State private var now = Date()
    private var cal: Calendar { Calendar.current }
    private var today: Date { cal.startOfDay(for: now) }
    private var upper: Date { cal.date(byAdding: .day, value: soonDays, to: today)! }
    
    @StateObject private var loc = LocationManager()
    
    @State private var nearbyOngoingCache: [(Exhibition, Double)] = []
    
    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671),
        span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
    )
    
    private var soonExhibitions: [Exhibition] {
        allExhibitions
            .filter { $0.endDate >= today && $0.endDate < upper }
            .sorted { $0.endDate < $1.endDate }
    }
    
    private func distanceKm(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        CLLocation(latitude: a.latitude, longitude: a.longitude)
            .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude)) / 1000.0
    }
    
    private func recomputeNearby() {
        guard let here = loc.location?.coordinate else {
            nearbyOngoingCache = []
            return
        }
        let today = Calendar.current.startOfDay(for: now)
        let running = allExhibitions.filter {
            $0.hasCoordinate && $0.startDate <= today && $0.endDate >= today
        }
        var paired: [(Exhibition, Double)] = []
        paired.reserveCapacity(running.count)
        for ex in running {
            if let c = ex.coordinate {
                paired.append((ex, distanceKm(c, here)))
            }
        }
        let limited = paired.filter { $0.1 <= nearbyRadiusKm }
        nearbyOngoingCache = limited.sorted { $0.1 < $1.1 }
    }
    
    private var nearbyPins: [MapPin] {
        var pins: [MapPin] = []
        if let here = loc.location?.coordinate {
            pins.append(.init(coordinate: here, title: "現在地", isHere: true))
        }
        for (ex, _) in nearbyOngoingCache.prefix(10) {
            if let c = ex.coordinate {
                pins.append(.init(coordinate: c, title: ex.title, isHere: false))
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
    
    var body: some View {
        NavigationStack {
            List {
                HomeSoonSectionView(soonDays: soonDays, exhibitions: soonExhibitions)
                
                HomeNearbySectionView(
                    nearbyRadiusKm: $nearbyRadiusKm,
                    mapRegion: $mapRegion,
                    authorization: loc.authorization,
                    items: nearbyOngoingCache,
                    pins: nearbyPins,
                    requestLocation: { loc.request() }
                )
            }
            .navigationTitle("ArtNote")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("抽出期間の選択", selection: $soonDays) {
                            Text("3日以内").tag(3)
                            Text("7日以内").tag(7)
                            Text("10日以内").tag(10)
                            Text("14日以内").tag(14)
                        }
                    } label: {
                        Label("抽出期間", systemImage: "slider.horizontal.3")
                    }
                }
            }
            .navigationDestination(for: Exhibition.self) { ex in
                ExhibitionDetailView(exhibition: ex)
            }
            .task { try? await ReminderService.shared.requestAuthorization() }
            .onChange(of: scenePhase) { phase in
                if phase == .active { now = Date() }
            }
            .onAppear {
                if loc.authorization == .notDetermined { loc.request() }
                recomputeNearby()
            }
            .onChange(of: hereKeyString) { _ in
                if let c = loc.location?.coordinate {
                    mapRegion.center = c
                    mapRegion.span = spanForRadius
                }
                recomputeNearby()
            }
            .onChange(of: nearbyRadiusKm) { _ in
                mapRegion.span = spanForRadius
                recomputeNearby()
            }
            // 件数だけ監視にして型推論を軽く
            .onChange(of: allExhibitions.count) { _ in
                recomputeNearby()
            }
        }
    }
}
