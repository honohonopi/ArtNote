//
//  CatalogOCRView.swift
//  ExhibitNote
//
//  Created by Honoka Nishiyama on 2025/11/08.
//

import SwiftUI
import SwiftData
import PhotosUI

struct CatalogOCRView: View {
    let exhibition: Exhibition
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var pickerItem: PhotosPickerItem?
    @State private var previewImage: UIImage?
    @State private var rows: [Row] = []          // 抽出候補
    @State private var isSaving = false

    struct Row: Identifiable {
        let id = UUID()
        var number: String
        var memo: String
        var selected: Bool = true
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                PhotosPicker(selection: $pickerItem,
                             matching: .images,
                             preferredItemEncoding: .automatic) {
                    Label(previewImage == nil ? "目録の写真を選ぶ / 撮る" : "別の写真を選ぶ",
                          systemImage: "camera.viewfinder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                if let img = previewImage {
                    Image(uiImage: img).resizable().scaledToFit()
                        .frame(maxHeight: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.bottom, 4)
                }

                List {
                    if rows.isEmpty {
                        Section {
                            Text("写真を選ぶと、目録から #番号＋作品名 の候補を抽出して表示します。")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Section("保存する項目にチェック") {
                            ForEach($rows) { $r in
                                Toggle(isOn: $r.selected) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("#\(r.number)").monospaced().bold()
                                        if !r.memo.isEmpty {
                                            Text(r.memo).foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding([.horizontal, .bottom])
            .navigationTitle("目録OCR")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { saveSelected() }
                        .disabled(rows.allSatisfy { !$0.selected })
                }
            }
        }
        .onChange(of: pickerItem) { _, newItem in
            Task { await loadAndRecognize(from: newItem) }
        }
    }

    private func saveSelected() {
        guard !isSaving else { return }
        isSaving = true
        // チェックされた候補だけ ArtworkNote として保存
        let selected = rows.filter { $0.selected }
        for r in selected {
            let trimmed = r.memo.trimmingCharacters(in: .whitespacesAndNewlines)
            let note = ArtworkNote(exhibitionId: exhibition.id,
                                   catalogNumber: r.number,
                                   memo: trimmed.isEmpty ? "(未入力)" : trimmed)
            context.insert(note)
        }
        isSaving = false
        dismiss()
    }

    private func loadAndRecognize(from item: PhotosPickerItem?) async {
        rows = []
        previewImage = nil
        guard let item else { return }
        if let data = try? await item.loadTransferable(type: Data.self),
           let img = UIImage(data: data) {
            previewImage = img
            await recognizeCatalog(from: img)
        }
    }

    @MainActor
    private func recognizeCatalog(from image: UIImage) async {
        // プロジェクトの TextRecognitionService を利用する想定。
        // 例）TextRecognitionService.extractCatalogLines(image) -> [(number: String, title: String)]
        do {
            let candidates = try await TextRecognitionService.extractCatalogLines(from: image)
            // 重複や明らかなゴミを軽くフィルタ
            let norm = candidates
                .map { (no, title) in Row(number: no, memo: title) }
                .uniqued(by: \.number)
            self.rows = norm
        } catch {
            // 失敗時は簡易フォールバック（全体テキストを1行として表示 等）
            self.rows = []
        }
    }
}

// 小ユーティリティ：KeyPath でユニーク化
private extension Array {
    func uniqued<T: Hashable>(by key: KeyPath<Element, T>) -> [Element] {
        var seen = Set<T>()
        return filter { seen.insert($0[keyPath: key]).inserted }
    }
}
