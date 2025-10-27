//
//  HomeView.swift
//  ArtNote
//
//  Created by Honoka Nishiyama on 2025/10/03.
//

// ホーム画面
import SwiftUI
import SwiftData
import CoreLocation

struct HomeView: View {
    @Environment(\.modelContext) private var context
    
    @Environment(\.scenePhase) private var scenePhase
    
    @AppStorage("soonDays") private var soonDays: Int = 7
    @Query(sort: [SortDescriptor(\Exhibition.endDate, order: .forward)])
    private var allExhibitions: [Exhibition]
    
    @State private var now = Date()
    private var cal: Calendar { Calendar.current }
    private var today: Date { cal.startOfDay(for: now) }
    private var upper: Date { cal.date(byAdding: .day, value: soonDays, to: today)! }
    
    private var soonExhibitions: [Exhibition] {
        allExhibitions
            .filter { $0.endDate >= today && $0.endDate < upper } // [今日, 7日後) みたいに半開区間
            .sorted { $0.endDate < $1.endDate }
    }
    
    @StateObject private var loc = LocationManager()
    @AppStorage("nearbyRadiusKm") private var nearbyRadiusKm: Double = 10
    
    private func distanceKm(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        let la = CLLocation(latitude: a.latitude, longitude: a.longitude)
        let lb = CLLocation(latitude: b.latitude, longitude: b.longitude)
        return la.distance(from: lb) / 1000.0
    }

    private var nearbyOngoing: [(Exhibition, Double)] {
        guard let here = loc.location?.coordinate else { return [] }
        let today = Calendar.current.startOfDay(for: now)
        return allExhibitions
            .filter { $0.hasCoordinate && $0.startDate <= today && $0.endDate >= today }
            .map { ($0, distanceKm($0.coordinate!, here)) }
            .filter { $0.1 <= nearbyRadiusKm }
            .sorted { $0.1 < $1.1 }
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("まもなく終了（\(soonDays)日以内）")) {
                    if soonExhibitions.isEmpty {
                        ContentUnavailableView("該当する展示はありません", systemImage: "checkmark.seal")
                    } else {
                        ForEach(soonExhibitions.prefix(5)) { ex in
                            NavigationLink(value: ex) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(ex.title).font(.headline)
                                    Text("\(ex.venue)｜〜 \(ex.endDate.ymdString)")
                                        .font(.subheadline).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                Section(header: Text("近くで開催中（\(Int(nearbyRadiusKm)) km以内）")) {
                    HStack {
                        Image(systemName: "figure.walk.circle")
                        Text("半径 \(Int(nearbyRadiusKm)) km")
                        Slider(value: $nearbyRadiusKm, in: 3...50, step: 1)
                    }
                    .padding(.vertical, 4)
                            switch loc.authorization {
                            case .authorizedAlways, .authorizedWhenInUse:
                                if nearbyOngoing.isEmpty {
                                    ContentUnavailableView("近くで開催中の展示はありません", systemImage: "mappin.and.ellipse")
                                } else {
                                    ForEach(nearbyOngoing.prefix(5), id: \.0.id) { ex, km in
                                        NavigationLink(value: ex) {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(ex.title).font(.headline)
                                                Text("\(ex.venue)｜〜 \(ex.endDate.ymdString)")
                                                    .font(.subheadline).foregroundStyle(.secondary)
                                                Text(String(format: "約 %.1f km", km))
                                                    .font(.caption).foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                }
                            case .notDetermined:
                                Button {
                                    loc.request()
                                } label: {
                                    Label("近くの展示を表示するには位置情報を許可", systemImage: "location")
                                }
                            default:
                                ContentUnavailableView("位置情報の許可が必要です", systemImage: "location.slash")
                            }
                        }
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
            .onAppear { if loc.authorization == .notDetermined { loc.request() } }
        }
    }
}
