//
//  ExhibitionFormView.swift
//  ArtNote
//
//  Created by Honoka Nishiyama on 2025/10/03.
//

import SwiftUI
import SwiftData
import PhotosUI

struct ExhibitionFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    
    @State private var title = ""
    @State private var venue = ""
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
    @State private var urlString: String = ""
    @State private var catalogTotalCountStr: String = ""
    
    @State private var showPhotoPicker = false
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var ocrAlertMessage: String? = nil
    @State private var showOcrAlert = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("基本情報") {
                    TextField("展覧会名", text: $title)
                    TextField("会場", text: $venue)
                    DatePicker("開始日", selection: $startDate, displayedComponents: .date)
                    DatePicker("終了日", selection: $endDate, in: startDate..., displayedComponents: .date)
                    TextField("公式URL（任意）", text: $urlString)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                }
                Section("ポスターから自動入力") {
                    Button {
                        showPhotoPicker = true
                    } label: {
                        Label("写真から会期を抽出", systemImage: "text.viewfinder")
                    }
                }
                .photosPicker(isPresented: $showPhotoPicker, selection: $selectedItem, matching: .images)
                .onChange(of: selectedItem) { _, newItem in
                    guard let item = newItem else { return }
                    Task {
                        do {
                            if let data = try await item.loadTransferable(type: Data.self),
                               let image = UIImage(data: data) {

                                let text = try await TextRecognitionService.recognizeText(from: image)
                                if let range = DateParsingService.extractDateRange(from: text) {
                                    // 既存の DatePicker に反映（会期内の順序保全）
                                    await MainActor.run {
                                        startDate = min(range.start, range.end)
                                        endDate   = max(range.start, range.end)
                                    }
                                } else {
                                    await MainActor.run {
                                        ocrAlertMessage = "会期らしき日付が見つかりませんでした。日付が写るように再撮影してみてください。"
                                        showOcrAlert = true
                                    }
                                }
                                let venueCands = VenueExtractionService.candidates(from: text)
                                await MainActor.run {
                                    if venue.isEmpty, let best = venueCands.first {
                                        venue = best
                                    }
                                }
                            } else {
                                await MainActor.run {
                                    ocrAlertMessage = "画像の読み込みに失敗しました。"
                                    showOcrAlert = true
                                }
                            }
                        } catch {
                            await MainActor.run {
                                ocrAlertMessage = "テキスト認識に失敗しました：\(error.localizedDescription)"
                                showOcrAlert = true
                            }
                        }
                    }
                }
                .alert(ocrAlertMessage ?? "", isPresented: $showOcrAlert) {
                    Button("OK", role: .cancel) { }
                }
                Section("目録") {
                    TextField("目録総数（例: 80）", text: $catalogTotalCountStr)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle("展示を追加")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || venue.isEmpty)
                }
            }
        }
    }
    
    private func save() {
        let total = Int(catalogTotalCountStr.trimmingCharacters(in: .whitespacesAndNewlines))
        let ex = Exhibition(title: title,
                            venue: venue,
                            startDate: startDate,
                            endDate: endDate,
                            url: URL(string: urlString),
                            catalogTotalCount: total)
        context.insert(ex)
        Task { await ReminderService.shared.scheduleDeadlineNotifications(for: ex) }
        dismiss()
    }
}
