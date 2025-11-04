//
//  CardPagingNoteView.swift
//  ArtNote
//
//  Created by Honoka Nishiyama on 2025/10/03.
//

// 鑑賞モード
import SwiftUI
import SwiftData

struct CardPagingNoteView: View {
    let exhibition: Exhibition
    var startIndex: Int? = nil   // ← 復元用（1始まりの表示番号）
    
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var overlay: AppOverlayState
    
    @State private var index: Int = 0
    @State private var saveSignal: Int = 0
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
                
                TabView(selection: $index) {
                    ForEach(Array(numbers.enumerated()), id: \.offset) { i, num in
                        NoteCard(
                            exhibitionId: exhibition.id,
                            catalogNumber: String(num),
                            saveSignal: $saveSignal
                        )
                        .padding(.horizontal, 16)
                        .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(maxHeight: 420)
                .padding(.top, 4)
                
                Spacer()
            }
            .padding()
            .navigationTitle("鑑賞モード")
            .toolbar {
                // ← 最小化：現在ページの“表示番号”を保存して閉じる
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        let currentNumber = numbers.indices.contains(index) ? numbers[index] : 1
                        overlay.minimized = .init(exhibition: exhibition, currentIndex: currentNumber)
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.down")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        saveSignal &+= 1
                        dismiss()
                    } label: { Text("完了") }
                }
            }
            // 復元用：startIndex が来ていたらその番号のカードへ
            .onAppear {
                if let s = startIndex, let i = numbers.firstIndex(of: s) {
                    index = i
                }
            }
        }
    }
}

/// 単一カード：#番号、保存済み表示、一言メモ入力
private struct NoteCard: View {
    let exhibitionId: String
    let catalogNumber: String
    @Binding var saveSignal: Int
    
    @Environment(\.modelContext) private var context
    @Query private var existing: [ArtworkNote]
    
    @State private var text: String = ""
    @State private var saved: Bool = false
    
    init(exhibitionId: String, catalogNumber: String, saveSignal: Binding<Int>) {
        self.exhibitionId = exhibitionId
        self.catalogNumber = catalogNumber
        _saveSignal = saveSignal
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
            
            // TextEditor をカード内で最大化
            TextEditor(text: $text)
                .scrollContentBackground(.hidden)
                .padding(8)
                .frame(minHeight: 160, maxHeight: .infinity, alignment: .topLeading)
                .background(
                    RoundedRectangle(cornerRadius: 8).fill(Color(.secondarySystemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8).stroke(.quaternary, lineWidth: 1)
                )
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
        .onChange(of: saveSignal) { _ in
            save()
        }
    }
    
    private func save() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // 何も入力されていない → 保存しない（既存があれば削除）
        guard !trimmed.isEmpty else {
            if let note = existing.first {
                context.delete(note)
            }
            saved = false
            return
        }
        
        // ② 入力あり → 保存（memo は必ず trimmed で）
        if let note = existing.first {
            note.memo = trimmed
            note.updatedAt = .now
        } else {
            let note = ArtworkNote(exhibitionId: exhibitionId,
                                   catalogNumber: catalogNumber,
                                   memo: trimmed)
            context.insert(note)
        }
        saved = true
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }
}
