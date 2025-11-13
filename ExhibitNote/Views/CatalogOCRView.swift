//
//  CatalogOCRView.swift
//  ExhibitNote
//
//  Created by Honoka Nishiyama on 2025/11/08.
//

import SwiftUI
import SwiftData
import PhotosUI
import CoreML

struct CatalogOCRView: View {
    let exhibition: Exhibition
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var pickerItem: PhotosPickerItem?
    @State private var previewImage: UIImage?
    @State private var originalImage: UIImage?      // クロップ用に渡す元画像
    @State private var showImageCropper = false     // TOCropViewController 表示フラグ
    @State private var rows: [Row] = []
    @State private var isSaving = false
    
    @Query private var allNotes: [ArtworkNote]
    @State private var classifiedLines: [ClassifiedTextFragment] = []

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
                .onChange(of: pickerItem) { newValue in
                    Task { await loadOriginalImage(from: newValue) }
                }
                
                if let img = previewImage {
                    Image(uiImage: img).resizable().scaledToFit().frame(maxHeight: 220)
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.secondary.opacity(0.3), lineWidth: 1))
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
                                // 対応する既存ノートを取得
                                let existingNote = note(for: r.number)

                                Toggle(isOn: $r.selected) {
                                    VStack(alignment: .leading, spacing: 4) {

                                        // ① 作品番号
                                        Text("#\(r.number)")
                                            .monospaced()
                                            .bold()

                                        // ② メモ（自分のメモを優先して表示）
                                        if let n = existingNote {
                                            let trimmedMemo = n.memo.trimmingCharacters(in: .whitespacesAndNewlines)
                                            if !trimmedMemo.isEmpty {
                                                Text(trimmedMemo)
                                                    .font(.subheadline)
                                            } else if !r.memo.isEmpty {
                                                // メモが空なら、OCR から拾ったタイトル候補も参考として表示
                                                Text(r.memo)
                                                    .font(.subheadline)
                                                    .foregroundStyle(.secondary)
                                            }
                                        } else if !r.memo.isEmpty {
                                            Text(r.memo)
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                        }

                                        // ③ 作者（小さく）
                                        if let artist = existingNote?.artist,
                                           !artist.isEmpty {
                                            Text(artist)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        } else {
                                            Text("作者：OCRで読み込めませんでした")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }

                                        // ④ 制作年（小さく）
                                        if let year = existingNote?.yearText,
                                           !year.isEmpty {
                                            Text(year)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        } else {
                                            Text("制作年：OCRで読み込めませんでした")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }

                                        // ⑤ 技法・材質（小さく）
                                        if let material = existingNote?.material,
                                           !material.isEmpty {
                                            Text(material)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        } else {
                                            Text("技法：OCRで読み込めませんでした")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }

                                        // ⑥ 所蔵（小さく）
                                        if let col = existingNote?.collection,
                                           !col.isEmpty {
                                            Text(col)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                        else {
                                           Text("所蔵：OCRで読み込めませんでした")
                                               .font(.caption2)
                                               .foregroundStyle(.secondary)
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
        .sheet(isPresented: $showImageCropper) {
            ImageCropper(image: $originalImage, isPresented: $showImageCropper) { cropped in
                previewImage = cropped
                Task { await recognizeCatalog(from: cropped) }
            }
        }
    }

    private func loadOriginalImage(from item: PhotosPickerItem?) async {
        rows = []
        previewImage = nil
        guard let item else { return }

        if let data = try? await item.loadTransferable(type: Data.self),
           let img = UIImage(data: data) {
            print("originalImage loaded: \(img.size)")
            await MainActor.run {
                self.originalImage = img
                self.showImageCropper = true   // ここで sheet を開く
            }
        }
    }
    
    private func saveSelected() {
        guard !isSaving else { return }
        isSaving = true

        let exId = exhibition.id
        let selected = rows.filter { $0.selected }

        do {
            for r in selected {
                let targetNumber = r.number
                let fd = FetchDescriptor<ArtworkNote>(
                    predicate: #Predicate<ArtworkNote> { note in
                        note.exhibitionId == exId && note.catalogNumber == targetNumber
                    }
                )

                let existing = try context.fetch(fd).first

                let note: ArtworkNote
                if let ex = existing {
                    note = ex
                } else {
                    // ② 無ければメモ空で新規作成
                    note = ArtworkNote(
                        exhibitionId: exId,
                        catalogNumber: r.number,
                        memo: ""
                    )
                    context.insert(note)
                }

                // ③ OCR行のテキストは「作品タイトル」として扱う
                let title = r.memo.trimmingCharacters(in: .whitespacesAndNewlines)
                if !title.isEmpty {
                    if (note.artworkTitle ?? "").isEmpty {
                        note.artworkTitle = title
                    }
                }

                note.updatedAt = Date()
            }

            try context.save()
        } catch {
            print("CatalogOCR save error:", error)
        }

        isSaving = false
        dismiss()
    }
    
    private func note(for number: String) -> ArtworkNote? {
        allNotes.first {
            $0.exhibitionId == exhibition.id &&
            $0.catalogNumber == number
        }
    }
    
    @MainActor
    private func recognizeCatalog(from image: UIImage) async {
        rows = []
        classifiedLines = []

        do {
            async let pairsTask = TextRecognitionService.extractCatalogLines(from: image)
            async let classifiedTask = TextRecognitionService.classifyLines(from: image)

            let pairs = try await pairsTask
            let classified = try await classifiedTask

            // ▼ここを差し替え
            let merged = TextRecognitionService().mergeArtistAndTitles(from: pairs as! [TextRecognitionService.CatalogItem])
            self.rows = merged.map { item in
                let numberString = item.number.map { String($0) } ?? ""
                return Row(number: numberString, memo: "\(item.artist) – \(item.title)")
            }

            self.classifiedLines = classified as! [ClassifiedTextFragment]

            // ▼デバッグ確認用（あとで消してOK）
            for m in merged {
                let numStr = m.number.map { String($0) } ?? ""
                print("[merged] #\(numStr) \(m.artist) – \(m.title)")
            }

        } catch {
            print("Catalog OCR failed:", error)
            self.rows = []
            self.classifiedLines = []
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

