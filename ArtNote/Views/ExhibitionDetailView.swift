//
//  ExhibitionDetailView.swift
//  ArtNote
//
//  Created by Honoka Nishiyama on 2025/10/03.
//

// 展覧会詳細
import SwiftUI
import SwiftData

struct ExhibitionDetailView: View {
    let exhibition: Exhibition
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    @State private var showDeleteConfirm = false
    @State private var showEdit = false
    
    @State private var pickedColor: Color = .blue
    
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
                        Text("\(exhibition.venue) / 〜 \(exhibition.endDate.ymdString)")
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
        .sheet(isPresented: $showEdit) {
            ExhibitionEditSheet(exhibition: exhibition)
                .presentationDetents([.large]) // 好みで .medium も可
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    // 共有
                    ShareLink(items: [exhibition.title, exhibition.venue]) {
                        Label("共有", systemImage: "square.and.arrow.up")
                    }
                    // カレンダーに追加
                    Button {
                        visitDate = min(max(Date(), exhibition.startDate), exhibition.endDate)
                        showPlanner = true
                    } label: {
                        Label("カレンダーに追加", systemImage: "calendar.badge.plus")
                    }
                    // 編集
                    Button {
                        showEdit = true
                    } label: {
                        Label("編集", systemImage: "pencil")
                    }
                    Divider()
                    // 削除
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("削除", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .onAppear {
            if let c = exhibition.uiColor {
                pickedColor = Color(c)
            } else {
                pickedColor = .blue
            }
        }
        .confirmationDialog(
            "本当に削除しますか？",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("削除", role: .destructive) { deleteExhibition() }
            Button("キャンセル", role: .cancel) {}
        }
    }
    
    private func deleteExhibition() {
        // 関連メモを巻き添え削除
        let exId = exhibition.id
        do {
            let fd = FetchDescriptor<ArtworkNote>(
                predicate: #Predicate { $0.exhibitionId == exId }
            )
            let related = try context.fetch(fd)
            related.forEach { context.delete($0) }
            
            // 展覧会本体を削除
            context.delete(exhibition)
            try context.save()
            
            // 画面を閉じる（一覧やカレンダーは @Query 経由で自動更新）
            dismiss()
        } catch {
            // TODO: アラート表示など（必要なら）
            print("Delete failed:", error)
        }
    }
}

private struct ExhibitionEditSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var venue: String
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var color: Color

    let exhibition: Exhibition

    init(exhibition: Exhibition) {
        self.exhibition = exhibition
        _title = State(initialValue: exhibition.title)
        _venue = State(initialValue: exhibition.venue)
        _startDate = State(initialValue: exhibition.startDate)
        _endDate = State(initialValue: exhibition.endDate)
        if let ui = exhibition.uiColor { _color = State(initialValue: Color(ui)) }
        else { _color = State(initialValue: .blue) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("基本情報") {
                    TextField("展覧会名", text: $title)
                    TextField("会場", text: $venue)
                    DatePicker("開始日", selection: $startDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .environment(\.locale, Locale(identifier: "ja_JP"))
                        .environment(\.calendar, Calendar(identifier: .gregorian))
                    DatePicker("終了日", selection: $endDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .environment(\.locale, Locale(identifier: "ja_JP"))
                        .environment(\.calendar, Calendar(identifier: .gregorian))
                }
                Section("帯の色") {
                    ColorPicker("色", selection: $color, supportsOpacity: false)
                }
            }
            .navigationTitle("編集")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        // 日付の整合性
                        if endDate < startDate { endDate = startDate }
                        // モデルへ反映
                        exhibition.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        exhibition.venue = venue.trimmingCharacters(in: .whitespacesAndNewlines)
                        exhibition.startDate = startDate
                        exhibition.endDate = endDate
                        exhibition.setColor(UIColor(color))
                        try? context.save()        // 即保存 → @Query 経由でUI更新
                        dismiss()
                    }
                }
            }
        }
    }
}
