//
//  HomeView.swift
//  ArtNote
//
//  Created by Honoka Nishiyama on 2025/10/03.
//

// ホーム画面
import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @State private var showAdd = false
    @State private var showCalendar = false
    
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
    
    var body: some View {
        NavigationStack {
            List {
                if soonExhibitions.isEmpty {
                        ContentUnavailableView("該当する展示はありません", systemImage: "checkmark.seal")
                } else {
                    Section(header: Text("まもなく終了（\(soonDays)日以内）")) {
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
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAdd = true } label: { Image(systemName: "plus") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                  Button { showCalendar = true } label: { Image(systemName: "calendar") }
                }
            }
            .sheet(isPresented: $showAdd) {
                ExhibitionFormView()
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showCalendar) {
              ExhibitionsCalendarView()
            }
            .navigationDestination(for: Exhibition.self) { ex in
                ExhibitionDetailView(exhibition: ex)
            }
            .task { try? await ReminderService.shared.requestAuthorization() }
            .onChange(of: scenePhase) { phase in
                if phase == .active { now = Date() }
            }

        }
    }
}
