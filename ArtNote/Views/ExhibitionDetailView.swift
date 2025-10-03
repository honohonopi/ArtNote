//
//  ExhibitionDetailView.swift
//  ArtNote
//
//  Created by Honoka Nishiyama on 2025/10/03.
//

import SwiftUI
import SwiftData

struct ExhibitionDetailView: View {
    let exhibition: Exhibition
    @Environment(\.modelContext) private var context
    
    @Query private var notes: [ArtworkNote]
    @State private var showQuick = false
    
    @State private var showPlanner = false
    @State private var visitDate = Date()
    @State private var showAddDone = false
    
    init(exhibition: Exhibition) {
        self.exhibition = exhibition
        let exId = exhibition.id
        _notes = Query(filter: #Predicate<ArtworkNote> { n in n.exhibitionId == exId },
                       sort: [SortDescriptor(\.catalogNumber, order: .forward)])
    }
    
    var body: some View {
        List {
            Section("") {
                HStack {
                    VStack(alignment: .leading) {
                        Text(exhibition.title).font(.title3).bold()
                        Text("\(exhibition.venue) / 〜 \(exhibition.endDate, style: .date)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button { showQuick = true } label: {
                        Label("鑑賞モード", systemImage: "square.and.pencil")
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            Section("メモ（\(notes.count)）") {
                ForEach(notes) { n in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("#\(n.catalogNumber)").font(.caption).monospaced()
                            Spacer()
                            Text(n.createdAt, style: .date).font(.caption).foregroundStyle(.secondary)
                        }
                        Text(n.memo).font(.body)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("詳細")
        .sheet(isPresented: $showQuick) {
            CardPagingNoteView(exhibition: exhibition)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showPlanner) {
            NavigationStack {
                Form {
                    Section("訪問日時") {
                        DatePicker("日付", selection: $visitDate,
                                   in: exhibition.startDate...exhibition.endDate,
                                   displayedComponents: .date)
                        DatePicker("開始時刻", selection: $visitDate,
                                   displayedComponents: .hourAndMinute)
                    }
                    Section {
                        Text("デフォルトで2時間枠を作成します（後からカレンダーで編集可能）。")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .navigationTitle("予定に追加")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("閉じる") { showPlanner = false } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("追加") {
                            Task {
                                // 権限
                                let granted = (try? await EventKitService.shared.requestAccess()) ?? false
                                guard granted else { return }
                                do {
                                    try EventKitService.shared.addVisitEvent(
                                        exhibition: exhibition,
                                        visitDate: visitDate,
                                        durationHours: 2
                                    )
                                    showPlanner = false
                                    showAddDone = true
                                } catch {
                                    // TODO: エラーハンドリング（アラート等）
                                }
                            }
                        }
                    }
                }
            }
        }
        .alert("カレンダーに追加しました", isPresented: $showAddDone) {
            Button("OK", role: .cancel) { }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(items: [exhibition.title, exhibition.venue]) { Image(systemName: "square.and.arrow.up") }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    // 会期内で初期値をクランプ
                    visitDate = min(max(Date(), exhibition.startDate), exhibition.endDate)
                    showPlanner = true
                } label: { Label("この日で行く", systemImage: "calendar.badge.plus") }
            }
        }
    }
}
