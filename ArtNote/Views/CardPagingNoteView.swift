//
//  CardPagingNoteView.swift
//  ArtNote
//
//  Created by Honoka Nishiyama on 2025/10/03.
//

import SwiftUI
import SwiftData

struct CardPagingNoteView: View {
    let exhibition: Exhibition
    @Environment(\.modelContext) private var context

    // ページインデックス（0始まり）
    @State private var index: Int = 0
    // 表示する番号の配列（1..N）。未設定なら仮で1..50
    private var numbers: [Int] {
        if let n = exhibition.catalogTotalCount, n > 0 { return Array(1...n) }
        return Array(1...50)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                // インジケータ
                Text("\(exhibition.title)")
                    .font(.headline).lineLimit(1).minimumScaleFactor(0.8)
                Text("目録 \(numbers[index]) / \(numbers.count)")
                    .font(.subheadline).foregroundStyle(.secondary)

                TabView(selection: $index) {
                    ForEach(Array(numbers.enumerated()), id: \.offset) { i, num in
                        NoteCard(exhibitionId: exhibition.id, catalogNumber: String(num))
                            .padding(.horizontal, 16)
                            .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(maxHeight: 360)

                HStack(spacing: 12) {
                    Button {
                        index = max(index - 1, 0)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: { Label("前へ", systemImage: "chevron.left") }
                    .buttonStyle(.bordered)

                    Button {
                        index = min(index + 1, numbers.count - 1)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: { Label("次へ", systemImage: "chevron.right") }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.top, 4)

                Spacer()
            }
            .padding()
            .navigationTitle("鑑賞モード")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        index = min(index + 1, numbers.count - 1)
                    } label: { Image(systemName: "arrow.right.circle") }
                }
            }
        }
    }
}

/// 単一カード：#番号、保存済み表示、一言メモ入力
private struct NoteCard: View {
    let exhibitionId: String
    let catalogNumber: String

    @Environment(\.modelContext) private var context
    @Query private var existing: [ArtworkNote]

    @State private var text: String = ""
    @State private var saved: Bool = false

    init(exhibitionId: String, catalogNumber: String) {
        self.exhibitionId = exhibitionId
        self.catalogNumber = catalogNumber
        _existing = Query(filter: #Predicate<ArtworkNote> { n in
            n.exhibitionId == exhibitionId && n.catalogNumber == catalogNumber
        })
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text("#\(catalogNumber)").font(.title2).monospaced().bold()
                Spacer()
                if saved || (existing.first?.memo.isEmpty == false) {
                    Label("保存済み", systemImage: "checkmark.circle.fill")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            TextField("一言メモ", text: $text, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .onAppear {
                    if let note = existing.first { text = note.memo }
                }

            Button {
                save()
            } label: {
                Label("保存", systemImage: "tray.and.arrow.down")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            // 片手操作向けに空白スペース
            Spacer(minLength: 0)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.quaternary, lineWidth: 1)
        )
    }

    private func save() {
        if let note = existing.first {
            note.memo = text
            note.updatedAt = .now
        } else {
            let note = ArtworkNote(exhibitionId: exhibitionId,
                                   catalogNumber: catalogNumber,
                                   memo: text)
            context.insert(note)
        }
        saved = true
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }
}
