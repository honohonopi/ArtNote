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
    @Query private var upcoming: [Exhibition]
    @State private var showAdd = false
    @State private var showCalendar = false
    
    init() {
        let now = Date()
        _upcoming = Query(filter: #Predicate<Exhibition> { ex in ex.endDate >= now },
                          sort: [SortDescriptor(\.endDate, order: .forward)])
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section("まもなく終了") {
                    ForEach(upcoming.prefix(5)) { ex in
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
            .navigationTitle("ArtNote")
            .toolbar {
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
        }
    }
}
