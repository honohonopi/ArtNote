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
    var startIndex: Int? = nil   // ← 復元用（管理用インデックス）
    
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var overlay: AppOverlayState
    
    @State private var index: Int = 0
    @State private var saveSignal: Int = 0
    @State private var indices: [Int] = []
    @State private var isAppending = false
    @State private var appendTask: Task<Void, Never>? = nil
    
    @Query private var existingNotes: [ArtworkNote]
    
    private let defaultPageCount = 50
    private let appendChunkSize = 50
    
    init(exhibition: Exhibition, startIndex: Int? = nil) {
        self.exhibition = exhibition
        self.startIndex = startIndex
        let exId = exhibition.id
        _existingNotes = Query(filter: #Predicate<ArtworkNote> { n in n.exhibitionId == exId })
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                // インジケータ
                Text("\(exhibition.title)")
                    .font(.headline).lineLimit(1).minimumScaleFactor(0.8)
                if !indices.isEmpty {
                    Text("ページ \(min(index + 1, indices.count))/\(indices.count)")
                        .font(.caption).foregroundStyle(.secondary)
                }
                
                TabView(selection: $index) {
                    ForEach(Array(indices.enumerated()), id: \.offset) { i, num in
                        NoteCard(
                            exhibitionId: exhibition.id,
                            catalogIndex: num,
                            fallbackDisplayNumber: String(num),
                            saveSignal: $saveSignal
                        )
                        .padding(.horizontal, 16)
                        .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(maxHeight: 420)
                .padding(.top, 4)
                
                if indices.count > 1 {
                    Slider(value: Binding(
                        get: { Double(index) },
                        set: { index = Int($0.rounded()) }
                    ), in: 0...Double(indices.count - 1), step: 1)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("鑑賞モード")
            .navigationBarTitleDisplayMode(.inline)
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .contentShape(Rectangle())
            .onTapGesture {
                dismissKeyboard()
            }
            .toolbar {
                // ← 最小化：現在ページの“表示番号”を保存して閉じる
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        let currentNumber = indices.indices.contains(index) ? indices[index] : 1
                        exhibition.lastViewedNoteIndex = currentNumber
                        overlay.minimized = .init(exhibition: exhibition, currentIndex: currentNumber)
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.down")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        saveSignal &+= 1
                        let currentNumber = indices.indices.contains(index) ? indices[index] : 1
                        exhibition.lastViewedNoteIndex = currentNumber
                        dismiss()
                    } label: { Text("完了") }
                }
            }
            // 復元用：startIndex が来ていたらその番号のカードへ
            .onAppear {
                if indices.isEmpty {
                    indices = initialIndices()
                }
                seedNotesIfNeeded()
                if let s = startIndex, let i = indices.firstIndex(of: s) {
                    index = i
                } else if let s = exhibition.lastViewedNoteIndex, let i = indices.firstIndex(of: s) {
                    index = i
                }
            }
            .onChange(of: index) { _, newValue in
                guard !exhibition.catalogImported else { return }
                guard !isAppending else { return }
                guard newValue >= indices.count - 2 else { return }
                appendTask?.cancel()
                appendTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    if Task.isCancelled { return }
                    guard index >= indices.count - 2 else { return }
                    isAppending = true
                    let start = (indices.last ?? 0) + 1
                    let end = start + appendChunkSize - 1
                    indices.append(contentsOf: start...end)
                    exhibition.noteCount = indices.count
                    isAppending = false
                }
            }
            .onDisappear {
                let currentNumber = indices.indices.contains(index) ? indices[index] : 1
                exhibition.lastViewedNoteIndex = currentNumber
            }
        }
    }
    
    private func initialIndices() -> [Int] {
        if exhibition.catalogImported {
            let knownCount = exhibition.catalogTotalCount ?? maxExistingIndex()
            let count = knownCount > 0 ? knownCount : defaultPageCount
            return Array(1...count)
        }
        let baseCount = exhibition.noteCount ?? defaultPageCount
        let count = max(baseCount, defaultPageCount)
        return Array(1...count)
    }
    
    private func maxExistingIndex() -> Int {
        existingNotes.map { $0.resolvedCatalogIndex }.max() ?? 0
    }
    
    private func seedNotesIfNeeded() {
        guard exhibition.catalogImported else { return }
        let existing = Set(existingNotes.map { $0.resolvedCatalogIndex })
        for num in indices where !existing.contains(num) {
            let note = ArtworkNote(
                exhibitionId: exhibition.id,
                catalogNumber: String(num),
                catalogIndex: num,
                memo: ""
            )
            context.insert(note)
        }
    }
    
    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil,
                                        from: nil,
                                        for: nil)
    }
}

/// 単一カード：#番号、保存済み表示、一言メモ入力
private struct NoteCard: View {
    let exhibitionId: String
    let catalogIndex: Int
    let fallbackDisplayNumber: String
    @Binding var saveSignal: Int
    
    @Environment(\.modelContext) private var context
    @Query private var existing: [ArtworkNote]
    
    @State private var text: String = ""
    @State private var saved: Bool = false
    @State private var autosaveTask: Task<Void, Never>? = nil
    @State private var hasEdited: Bool = false
    @State private var isInitializing: Bool = true
    
    init(exhibitionId: String, catalogIndex: Int, fallbackDisplayNumber: String, saveSignal: Binding<Int>) {
        self.exhibitionId = exhibitionId
        self.catalogIndex = catalogIndex
        self.fallbackDisplayNumber = fallbackDisplayNumber
        _saveSignal = saveSignal
        let indexValue = catalogIndex
        let fallbackValue = fallbackDisplayNumber
        _existing = Query(filter: #Predicate<ArtworkNote> { n in
            n.exhibitionId == exhibitionId &&
            (n.catalogIndex == indexValue || n.catalogNumber == fallbackValue)
        })
    }
    
    var body: some View {
        let displayNumber = existing.first?.resolvedDisplayNumber ?? fallbackDisplayNumber
        let hasSavedMemo = existing.first?.memo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        let showSaved = saved || hasSavedMemo
        
        VStack(spacing: 14) {
            HStack {
                Text("#\(displayNumber)").font(.title2).monospaced().bold()
                Spacer()
                if showSaved {
                    Label("保存済み", systemImage: "checkmark.circle.fill")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            
            if let note = existing.first {
                artworkHeader(note)
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
                    if let note = existing.first {
                        text = note.memo
                        if note.catalogIndex == nil {
                            note.catalogIndex = catalogIndex
                        }
                        if note.displayCatalogNumber == nil,
                           note.catalogNumber != displayNumber {
                            note.displayCatalogNumber = displayNumber
                        }
                    }
                    DispatchQueue.main.async {
                        isInitializing = false
                    }
                }
            Spacer(minLength: 0)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.quaternary, lineWidth: 1)
        )
        .onChange(of: text) { _ in
            saved = false
            if !isInitializing {
                hasEdited = true
                scheduleAutosave()
            }
        }
        .onChange(of: saveSignal) { _ in
            save()
        }
        .onDisappear {
            autosaveTask?.cancel()
            save()
        }
    }
    
    private func save() {
        guard hasEdited else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.isEmpty {
            if let note = existing.first {
                context.delete(note)
            }
            saved = false
            hasEdited = false
            return
        }
        
        if let note = existing.first {
            note.memo = trimmed
            note.updatedAt = .now
        } else {
            let displayValue = fallbackDisplayNumber == String(catalogIndex)
            ? nil
            : fallbackDisplayNumber
            let note = ArtworkNote(exhibitionId: exhibitionId,
                                   catalogNumber: String(catalogIndex),
                                   catalogIndex: catalogIndex,
                                   displayCatalogNumber: displayValue,
                                   memo: trimmed)
            context.insert(note)
        }
        saved = true
        hasEdited = false
    }
    
    private func scheduleAutosave() {
        autosaveTask?.cancel()
        autosaveTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 400_000_000)
            if Task.isCancelled { return }
            save()
        }
    }
    
    @ViewBuilder
    private func artworkHeader(_ note: ArtworkNote) -> some View {
        let title = note.artworkTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
        let artist = note.artist?.trimmingCharacters(in: .whitespacesAndNewlines)
        let yearText = note.yearText?.trimmingCharacters(in: .whitespacesAndNewlines)
        let material = note.material?.trimmingCharacters(in: .whitespacesAndNewlines)
        let collection = note.collection?.trimmingCharacters(in: .whitespacesAndNewlines)
        let infoLines = [yearText, material, collection].compactMap { $0 }.filter { !$0.isEmpty }
        
        if (title?.isEmpty == false) || (artist?.isEmpty == false) || !infoLines.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                if let t = title, !t.isEmpty {
                    Text(t).font(.headline)
                }
                if let a = artist, !a.isEmpty {
                    Text(a).font(.subheadline).foregroundStyle(.secondary)
                }
                if !infoLines.isEmpty {
                    Text(infoLines.joined(separator: " / "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
