//
//  ExhibitionEditView.swift
//  ArtNote
//
//  Created by Honoka Nishiyama on 2025/10/28.
//

import SwiftUI
import CoreData

struct ExhibitionEditView: View {
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
