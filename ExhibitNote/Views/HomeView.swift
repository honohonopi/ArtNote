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
    let id: String
    let coordinate: CLLocationCoordinate2D
    let title: String
    let isHere: Bool
    let exhibition: Exhibition?
}

struct NearbyMiniMapView: View {
    @Binding var region: MKCoordinateRegion
    let pins: [MapPin]
    @Binding var selectedPinID: String?
    
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
                    NavigationLink {
                        ExhibitionDetailView(exhibition: ex)
                    } label: {
                        ExhibitionRowView(ex: ex, distanceKm: nil)
                    }
                    .id("soon-\(ex.id)")
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
    let displayLimit: Int
    let pins: [MapPin]
    let requestLocation: () -> Void
    let onRadiusEditingChanged: (Bool) -> Void
    
    @Binding var selectedPinID: String?          // ← Map の選択状態を受け取る
    @Binding var highlightedExID: String?
    
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
                    ForEach(Array(items.prefix(displayLimit)), id: \.0.id) { ex, km in
                        NavigationLink {
                            ExhibitionDetailView(exhibition: ex)
                        } label: {
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
                        .id("nearby-\(ex.id)")
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

struct HomeSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("userAdmissionCategory") private var userAdmissionCategoryRaw = UserTicketCategory.adult.rawValue
    @AppStorage("userDisplayName") private var userDisplayName = ""
    @AppStorage("includeVisitedSuggestions") private var includeVisitedSuggestions = false
    @AppStorage("notifyDeadlineEnabled") private var notifyDeadlineEnabled = true
    @AppStorage("notifyDeadlineHour") private var notifyDeadlineHour: Int = 9
    @AppStorage("notifyDeadlineMinute") private var notifyDeadlineMinute: Int = 0
    @AppStorage("notifyNearbyOngoingEnabled") private var notifyNearbyOngoingEnabled = false
    @AppStorage("notifyNearbyRadiusKm") private var notifyNearbyRadiusKm: Double = 10
    @Query(sort: [SortDescriptor(\Exhibition.endDate, order: .forward)]) private var allExhibitions: [Exhibition]

    var body: some View {
        NavigationStack {
            Form {
                // v0では未使用のため非表示
                Section("提案") {
                    Toggle("訪問済みも提案に含める", isOn: $includeVisitedSuggestions)
                }
                Section {
                    Toggle(isOn: $notifyDeadlineEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("間もなく終了する展覧会を通知する")
                            Text("会期終了1週間前と1日前に通知します")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    DatePicker(
                        "通知時刻",
                        selection: Binding(
                            get: {
                                Calendar.current.date(from: DateComponents(hour: notifyDeadlineHour, minute: notifyDeadlineMinute)) ?? Date()
                            },
                            set: { newValue in
                                let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                                notifyDeadlineHour = comps.hour ?? 9
                                notifyDeadlineMinute = comps.minute ?? 0
                            }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                    .disabled(!notifyDeadlineEnabled)
                    .onChange(of: notifyDeadlineEnabled) { _, _ in
                        rescheduleNotifications()
                    }
                    .onChange(of: notifyDeadlineHour) { _, _ in
                        rescheduleNotifications()
                    }
                    .onChange(of: notifyDeadlineMinute) { _, _ in
                        rescheduleNotifications()
                    }
                    Toggle("近くで開館中の展示を通知する", isOn: $notifyNearbyOngoingEnabled)
                    Picker("通知の半径", selection: $notifyNearbyRadiusKm) {
                        Text("3km").tag(3.0)
                        Text("5km").tag(5.0)
                        Text("10km").tag(10.0)
                        Text("20km").tag(20.0)
                        Text("50km").tag(50.0)
                    }
                    .disabled(!notifyNearbyOngoingEnabled)
                } header: {
                    Text("通知")
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    private func rescheduleNotifications() {
        let time = DateComponents(hour: notifyDeadlineHour, minute: notifyDeadlineMinute)
        Task {
            await ReminderService.shared.rescheduleAllNotifications(
                exhibitions: allExhibitions,
                isEnabled: notifyDeadlineEnabled,
                notificationTime: time
            )
        }
    }
}

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    
    @AppStorage("soonDays") private var soonDays: Int = 7
    @AppStorage("nearbyRadiusKm") private var nearbyRadiusKm: Double = 10
    @AppStorage("notifyNearbyRadiusKm") private var notifyNearbyRadiusKm: Double = 10
    @AppStorage("notifyNearbyOngoingEnabled") private var notifyNearbyOngoingEnabled = false
    @AppStorage("notifyNearbyLastDate") private var notifyNearbyLastDate = ""
    
    @Query(sort: [SortDescriptor(\Exhibition.endDate, order: .forward)])
    private var allExhibitions: [Exhibition]
    
    @State private var now = Date()
    private var cal: Calendar { Calendar.current }
    private var today: Date { cal.startOfDay(for: now) }
    private var upper: Date { cal.date(byAdding: .day, value: soonDays, to: today)! }
    
    @StateObject private var loc = LocationManager()
    
    @State private var nearbyOngoingCache: [(Exhibition, Double)] = []
    @State private var isAdjustingRadius = false
    
    @State private var selectedPinID: String? = nil
    @State private var highlightedExID: String? = nil
    @State private var showSettings = false
    
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

    private var nearbyDisplayLimit: Int { 5 }
    
    private var nearbyPins: [MapPin] {
        var pins: [MapPin] = []
        if let here = loc.location?.coordinate {
            pins.append(.init(id: "here", coordinate: here, title: "現在地", isHere: true, exhibition: nil))
        }
        for (ex, _) in nearbyOngoingCache.prefix(nearbyDisplayLimit) {
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
                HomeSoonSectionView(soonDays: $soonDays, exhibitions: soonExhibitions)
                
                HomeNearbySectionView(
                    nearbyRadiusKm: $nearbyRadiusKm,
                    mapRegion: $mapRegion,
                    authorization: loc.authorization,
                    items: nearbyOngoingCache,
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
                    checkNearbyOngoingNotification()
                }
                .onChange(of: hereKeyString) { _ in
                    if let c = loc.location?.coordinate {
                        mapRegion.center = c
                        mapRegion.span = spanForRadius
                    }
                    recomputeNearby()
                    checkNearbyOngoingNotification()
                }
                // 件数だけ監視にして型推論を軽く
                .onChange(of: allExhibitions.count) { _ in
                    recomputeNearby()
                    checkNearbyOngoingNotification()
                }
                .onChange(of: notifyNearbyOngoingEnabled) { _, _ in
                    checkNearbyOngoingNotification()
                }
                .onChange(of: notifyNearbyRadiusKm) { _, _ in
                    checkNearbyOngoingNotification()
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
                    HomeSettingsView()
                }
            }
        }
    }

    private func checkNearbyOngoingNotification() {
        guard notifyNearbyOngoingEnabled else { return }
        guard loc.location?.coordinate != nil else { return }
        let todayKey = ymdKey(now)
        guard notifyNearbyLastDate != todayKey else { return }
        guard let target = nearbyOngoingCache.first(where: { isNotifyTarget($0.0, now: now, distanceKm: $0.1) }) else { return }
        notifyNearbyLastDate = todayKey
        Task {
            await ReminderService.shared.scheduleNearbyOngoingNotification(
                for: target.0,
                identifier: "nearby_\(todayKey)"
            )
        }
    }

    private func isNotifyTarget(_ exhibition: Exhibition, now: Date, distanceKm: Double) -> Bool {
        guard distanceKm <= notifyNearbyRadiusKm else { return false }
        let status = ExhibitionScheduleUtils.openingStatus(on: now, exhibition: exhibition)
        guard case .open(let openTime, let closeTime, let lastEntryTime) = status else { return false }
        if let open = timeOnToday(openTime, now: now), now < open { return false }
        let cutoff: Date
        if let last = timeOnToday(lastEntryTime, now: now) {
            cutoff = Calendar.current.date(byAdding: .minute, value: -30, to: last) ?? last
        } else if let close = timeOnToday(closeTime, now: now) {
            cutoff = Calendar.current.date(byAdding: .minute, value: -60, to: close) ?? close
        } else {
            cutoff = Calendar.current.date(bySettingHour: 16, minute: 0, second: 0, of: now) ?? now
        }
        return now <= cutoff
    }

    private func timeOnToday(_ timeString: String?, now: Date) -> Date? {
        guard let timeString else { return nil }
        let trimmed = timeString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != "未設定" else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        guard let time = formatter.date(from: trimmed) else { return nil }
        let comps = Calendar.current.dateComponents([.hour, .minute], from: time)
        return Calendar.current.date(bySettingHour: comps.hour ?? 0, minute: comps.minute ?? 0, second: 0, of: now)
    }

    private func ymdKey(_ date: Date) -> String {
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: date)
        guard let y = comps.year, let m = comps.month, let d = comps.day else { return "" }
        return String(format: "%04d-%02d-%02d", y, m, d)
    }
}
