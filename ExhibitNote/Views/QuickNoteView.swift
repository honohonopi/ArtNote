//
//  QuickNoteView.swift
//  ArtNote
//
//  Created by Honoka Nishiyama on 2025/10/03.
//

// クイックメモ
import SwiftUI
import SwiftData

struct QuickNoteView: View {
    let exhibition: Exhibition
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    @State private var catalogNumber: String = ""
    @State private var memo: String = ""
    @FocusState private var focused: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text(exhibition.title)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                HStack(spacing: 12) {
                    TextField("目録番号", text: $catalogNumber)
                        .keyboardType(.numbersAndPunctuation)
                        .textFieldStyle(.roundedBorder)
                        .focused($focused)
                        .frame(width: 120)
                    
                    TextField("一言メモ", text: $memo, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                }
                
                Button(action: save) {
                    Label("保存", systemImage: "tray.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(catalogNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || memo.isEmpty)
                
                Spacer()
            }
            .padding()
            .onAppear { focused = true }
            .navigationTitle("鑑賞モード")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("閉じる") { dismiss() } } }
        }
    }
    
    private func save() {
        let note = ArtworkNote(exhibitionId: exhibition.id, catalogNumber: catalogNumber, memo: memo)
        context.insert(note)
        catalogNumber = ""; memo = ""; UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
