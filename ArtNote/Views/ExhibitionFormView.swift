//
//  ExhibitionFormView.swift
//  ArtNote
//
//  Created by Honoka Nishiyama on 2025/10/03.
//

// 展覧会登録フォーム
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
    
    // 候補と選択
    @State private var titleOptions: [String] = []
    @State private var venueOptions: [String] = []
    @State private var dateOptions: [(Date, Date)] = []
    
    @State private var selectedTitle: String?
    @State private var selectedVenue: String?
    @State private var selectedDateIndex: Int = 0
    
    // UI制御
    @State private var showReviewSheet = false
    @State private var showMissingAlert = false
    @State private var missingAlertMessage: String = ""
    
    @State private var pendingAlertMessage: String? = nil
    
    // 表示用フォーマッタ
    private var ymdFormatter: DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "yyyy/MM/dd"
        return f
    }
    
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
//                .photosPicker(isPresented: $showPhotoPicker, selection: $selectedItem, matching: .images)
                .onChange(of: selectedItem) { _, newItem in
                    guard let item = newItem else { return }
                    Task {
                        do {
                            if let data = try await item.loadTransferable(type: Data.self),
                               let image = UIImage(data: data) {
                                
                                // 画像 -> テキスト
                                let text = try await TextRecognitionService.recognizeText(from: image)
                                
                                // 各候補を抽出
                                let tCands = TitleExtractionService.candidates(from: text)
                                let vCands = VenueExtractionService.candidates(from: text)
                                let dCands = DateParsingService.candidates(from: text)
                                print("Date candidates:", dCands.map { ("\($0.0)", "\($0.1)") })
                                
                                // まずは既定値として 1件だけなら自動採用
                                await MainActor.run {
                                    // 展覧会名
                                    self.titleOptions = tCands
                                    if self.title.isEmpty, let first = tCands.first { self.title = first }
                                    self.selectedTitle = self.title
                                    
                                    // 会場
                                    self.venueOptions = vCands
                                    if self.venue.isEmpty, let first = vCands.first { self.venue = first }
                                    self.selectedVenue = self.venue
                                    
                                    // 会期
                                    self.dateOptions = dCands
                                    if let first = dCands.first {
                                        self.startDate = min(first.0, first.1)
                                        self.endDate   = max(first.0, first.1)
                                        self.selectedDateIndex = 0
                                    }
                                }
                                
                                // 不足アラート（何か1つでも取れなかった）
                                let missing = [
                                    tCands.isEmpty ? "展覧会名" : nil,
                                    vCands.isEmpty ? "会場名"   : nil,
                                    dCands.isEmpty ? "会期"     : nil
                                ].compactMap { $0 }
                                let message = missing.isEmpty ? nil : "以下の項目が読み取れませんでした：\n・" + missing.joined(separator: "\n・")
                                
                                let needsReview = (tCands.count >= 2) || (vCands.count >= 2) || (dCands.count >= 2)
                                await MainActor.run {
                                    if needsReview {
                                        // まずはシートだけ出す。アラートは保留
                                        self.pendingAlertMessage = message
                                        self.showReviewSheet = true
                                    } else if let msg = message {
                                        // シート不要なら即アラート
                                        self.missingAlertMessage = msg
                                        self.showMissingAlert = true
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
                .alert(missingAlertMessage, isPresented: $showMissingAlert) {
                    Button("OK", role: .cancel) {}
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
            .sheet(isPresented: $showReviewSheet) {
                NavigationStack {
                    Form {
                        // タイトル候補
                        if !titleOptions.isEmpty {
                            Section("展覧会名（候補）") {
                                ForEach(titleOptions, id: \.self) { t in
                                    HStack {
                                        Text(t)
                                        Spacer()
                                        if selectedTitle == t { Image(systemName: "checkmark") }
                                    }
                                    .contentShape(Rectangle())
                                    .onTapGesture { selectedTitle = t }
                                }
                            }
                        }
                        
                        // 会場候補
                        if !venueOptions.isEmpty {
                            Section("会場名（候補）") {
                                ForEach(venueOptions, id: \.self) { v in
                                    HStack {
                                        Text(v)
                                        Spacer()
                                        if selectedVenue == v { Image(systemName: "checkmark") }
                                    }
                                    .contentShape(Rectangle())
                                    .onTapGesture { selectedVenue = v }
                                }
                            }
                        }
                        
                        // 会期候補
                        if !dateOptions.isEmpty {
                            Section("会期（候補）") {
                                ForEach(Array(dateOptions.enumerated()), id: \.offset) { idx, pair in
                                    let label = "\(ymdFormatter.string(from: min(pair.0, pair.1))) 〜 \(ymdFormatter.string(from: max(pair.0, pair.1)))"
                                    HStack {
                                        Text(label)
                                        Spacer()
                                        if selectedDateIndex == idx { Image(systemName: "checkmark") }
                                    }
                                    .contentShape(Rectangle())
                                    .onTapGesture { selectedDateIndex = idx }
                                }
                            }
                        }
                    }
                    .navigationTitle("抽出結果を確認")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("閉じる") { showReviewSheet = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("反映") {
                                if let t = selectedTitle { title = t }
                                if let v = selectedVenue { venue = v }
                                if dateOptions.indices.contains(selectedDateIndex) {
                                    let p = dateOptions[selectedDateIndex]
                                    startDate = min(p.0, p.1); endDate = max(p.0, p.1)
                                }
                                showReviewSheet = false
                                
                                if let msg = pendingAlertMessage {
                                    pendingAlertMessage = nil
                                    // 少し遅延してから出すと確実
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                        missingAlertMessage = msg
                                        showMissingAlert = true
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedItem, matching: .images)
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
