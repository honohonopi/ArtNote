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
    let exhibition: Exhibition?
}

struct NearbyMiniMapView: View {
    @Binding var region: MKCoordinateRegion
    let pins: [MapPin]
    @Binding var selectedPinID: UUID?
    
    var body: some View {
                Map(
                    coordinateRegion: $region,
                    interactionModes: [.zoom, .pan],
                    showsUserLocation: false,
                    annotationItems: pins
                ) { (pin: MapPin) in
                    MapAnnotation(coordinate: pin.coordinate) {
                        // タップで選択状態を更新 → リスト側がハイライト＆スクロール
                        Button {
                            selectedPinID = pin.id
                        } label: {
                            Image(systemName: pin.isHere ? "mappin.circle.fill" : "mappin.circle")
                                .font(.title3)
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(
                                    pin.isHere ? Color.accentColor : (selectedPinID == pin.id ? Color.red : Color.gray)
                                )
                                .padding(4)
                                .background(.thinMaterial, in: Circle().inset(by: -2))
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                    }
                }
    }
}

struct HomeSoonSectionView: View {
    @Binding var soonDays: Int
    let exhibitions: [Exhibition]
    @State private var showPicker = false
    
    var body: some View {
        Section {
            if exhibitions.isEmpty {
                ContentUnavailableView("該当する展示はありません", systemImage: "calendar.circle")
            } else {
                ForEach(Array(exhibitions.prefix(5))) { ex in
                    NavigationLink(value: ex) {
                        ExhibitionRowView(ex: ex, distanceKm: nil)
                    }
                }
            }
            
        } header: {
            HStack(alignment: .firstTextBaseline) {
                Text("まもなく終了")
                Spacer()
                // 現在の抽出日数を表示（任意）
                Text("\(soonDays)日以内")
                // アイコンからPickerを展開
                Menu {
                    Picker("抽出期間の選択", selection: $soonDays) {
                        Text("3日以内").tag(3)
                        Text("7日以内").tag(7)
                        Text("10日以内").tag(10)
                        Text("14日以内").tag(14)
                    }
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
                .menuStyle(.automatic)
            }
        }
    }
}

struct HomeNearbySectionView: View {
    @Binding var nearbyRadiusKm: Double
    @Binding var mapRegion: MKCoordinateRegion
    
    let authorization: CLAuthorizationStatus
    let items: [(Exhibition, Double)]
    let pins: [MapPin]
    let requestLocation: () -> Void
    let onRadiusEditingChanged: (Bool) -> Void
    
    @Binding var selectedPinID: UUID?          // ← Map の選択状態を受け取る
    @State private var highlightedExID: PersistentIdentifier? = nil  // SwiftData の ID 型
    
    var body: some View {
        Section {
            if (authorization == .authorizedAlways || authorization == .authorizedWhenInUse),
               !pins.isEmpty {
                NearbyMiniMapView(region: $mapRegion, pins: pins, selectedPinID: $selectedPinID)
                    .aspectRatio(1, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            switch authorization {
            case .authorizedAlways, .authorizedWhenInUse:
                if items.isEmpty {
                    ContentUnavailableView("近くで開催中の展示はありません", systemImage: "mappin.and.ellipse")
                } else {
                    ScrollViewReader { proxy in
                        ForEach(Array(items.prefix(5)), id: \.0.id) { ex, km in
                            NavigationLink(value: ex) {
                                ExhibitionRowView(ex: ex, distanceKm: km)
                                    .padding(.vertical, 4)
                            }
                            .overlay(alignment: .leading) {
                                if highlightedExID == ex.id {
                                    Rectangle()
                                        .fill(Color.red.opacity(0.5))
                                        .frame(width: 4)
                                        .transition(.opacity.combined(with: .move(edge: .leading)))
                                }
                            }
                            .animation(.easeInOut(duration: 0.25), value: highlightedExID)
                            .id(ex.id)
                        }
                        .onChange(of: selectedPinID) { _, newID in
                            guard let pid = newID,
                                  let pin = pins.first(where: { $0.id == pid }),
                                  let ex = pin.exhibition
                            else {
                                highlightedExID = nil
                                return
                            }
                            highlightedExID = ex.id
                            // 少し遅延してスクロール（描画安定のため）
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                withAnimation(.easeInOut) {
                                    proxy.scrollTo(ex.id, anchor: .center)
                                }
                            }
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
        } header: {
            HStack(alignment: .firstTextBaseline) {
                Text("近くで開催中")
                Spacer()
                Text("\(Int(nearbyRadiusKm))km")
                Menu {
                    Picker("範囲の選択", selection: Binding(
                        get: { Int(nearbyRadiusKm) },
                        set: { newVal in
                            nearbyRadiusKm = Double(newVal)
                            onRadiusEditingChanged(false)
                        }
                    )) {
                        Text("3km").tag(3)
                        Text("5km").tag(5)
                        Text("10km").tag(10)
                        Text("20km").tag(20)
                        Text("50km").tag(50)
                    }
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .imageScale(.medium)
                        .padding(.leading, 6)
                }
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
    @State private var isAdjustingRadius = false
    
    @State private var selectedPinID: UUID? = nil
    
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
            pins.append(.init(coordinate: here, title: "現在地", isHere: true, exhibition: nil))
        }
        for (ex, _) in nearbyOngoingCache.prefix(10) {
            if let c = ex.coordinate {
                pins.append(.init(coordinate: c, title: ex.title, isHere: false, exhibition: ex)) // ← ここで紐付け
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
                HomeSoonSectionView(soonDays: $soonDays, exhibitions: soonExhibitions)
                
                HomeNearbySectionView(
                    nearbyRadiusKm: $nearbyRadiusKm,
                    mapRegion: $mapRegion,
                    authorization: loc.authorization,
                    items: nearbyOngoingCache,
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
                    selectedPinID: $selectedPinID
                )
            }
            .navigationTitle("ホーム")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // あとでアプリ設定用の画面を実装
            }
            .navigationDestination(for: Exhibition.self) { ex in
                ExhibitionDetailView(exhibition: ex)
            }
            .task { try? await ReminderService.shared.requestAuthorization() }
            // 近接半径が変わっても、ドラッグ中は重い更新をしない
            .onChange(of: nearbyRadiusKm) { _ in
                guard !isAdjustingRadius else { return }
                mapRegion.span = spanForRadius
                recomputeNearby()
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
            // 件数だけ監視にして型推論を軽く
            .onChange(of: allExhibitions.count) { _ in
                recomputeNearby()
            }
        }
    }
}

