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
import CoreLocation
import MapKit

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
    
    @State private var pickedColor: Color? = nil
    @State private var autoColor: UIColor? = nil
    
    @State private var mapPickerPayload: MapPickerPayload? = nil
    @State private var tempCoordinate: CLLocationCoordinate2D?
    
    @State private var previewRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671),
        span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
    )
    
    @State private var mapInitialQuery: String? = nil
    @State private var addressLine = ""
    
    struct MapPickerPayload: Identifiable {
        let id = UUID()
        let query: String
    }
    
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
                        .onSubmit {
                            triggerGeocoding()
                        }
                    HStack(spacing: 8) {
                        TextField("会場住所（任意）", text: $addressLine)   // ← 住所用の @State を持っていなければ追加
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                        Button {
                            // 住所があれば住所、なければ会場名。空なら何もしない
                            let q = addressLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? venue.trimmingCharacters(in: .whitespacesAndNewlines)
                            : addressLine.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !q.isEmpty else { return }
                            mapPickerPayload = MapPickerPayload(query: q)   // ← これでシートを開く
                        } label: {
                            Image(systemName: "mappin.and.ellipse")
                                .imageScale(.large)
                                .foregroundStyle(.blue)   // ← 青に
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("地図で位置を選ぶ")
                    }
                    DatePicker("開始日", selection: $startDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .environment(\.locale, Locale(identifier: "ja_JP"))
                        .environment(\.calendar, Calendar(identifier: .gregorian))
                    DatePicker("終了日", selection: $endDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .environment(\.locale, Locale(identifier: "ja_JP"))
                        .environment(\.calendar, Calendar(identifier: .gregorian))
                    TextField("公式URL（任意）", text: $urlString)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                }
                Section("ポスターから自動入力") {
                    Button {
                        showPhotoPicker = true
                    } label: {
                        Label("写真から情報を抽出", systemImage: "text.viewfinder")
                    }
                }
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
                                
                                if let dom = DominantColorService.dominantColor(from: image) {
                                    await MainActor.run {
                                        self.autoColor = dom
                                        self.pickedColor = Color(dom)   // ColorPicker の初期値
                                    }
                                }
                                
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
                Section("色を選択") {
                    HStack {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(pickedColor ?? (autoColor.map { Color($0) } ?? Color.blue))
                            .frame(width: 24, height: 24)
                        
                        ColorPicker(
                            "帯の色",
                            selection: Binding(
                                get: { pickedColor ?? (autoColor.map { Color($0) } ?? .blue) },
                                set: { pickedColor = $0 } // 選ばれたら上書き
                            ),
                            supportsOpacity: false
                        )
                    }
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
            .sheet(item: $mapPickerPayload) { payload in
                NavigationStack {
                    MapPickerView(seed: tempCoordinate, initialQuery: payload.query) { pickedCoord, pickedAddress in
                        // 座標を反映
                        tempCoordinate = pickedCoord
                        previewRegion.center = pickedCoord
                        previewRegion.span = .init(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        // 住所を反映（未入力なら反映／常に上書き、好みで）
                        if let addr = pickedAddress, !addr.isEmpty {
                            if addressLine.isEmpty {
                                addressLine = addr
                            } else {
                            }
                        }
                    }
                }
            }
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedItem, matching: .images)
    }
    
    private func save() {
        print(addressLine.trimmingCharacters(in: .whitespacesAndNewlines))
        let total = Int(catalogTotalCountStr.trimmingCharacters(in: .whitespacesAndNewlines))
        let ex = Exhibition(title: title,
                            venue: venue,
                            address: addressLine.trimmingCharacters(in: .whitespacesAndNewlines),
                            startDate: startDate,
                            endDate: endDate,
                            url: URL(string: urlString),
                            catalogTotalCount: total)
        if let c = tempCoordinate {
            ex.setCoordinate(c)
        }
        if let ui = (pickedColor.map { UIColor($0) } ?? autoColor) {
            ex.setColor(ui)
        }
        
        context.insert(ex)
        Task { await ReminderService.shared.scheduleDeadlineNotifications(for: ex) }
        dismiss()
    }
    
    private func triggerGeocoding() {
        Task {
            let v = venue.trimmingCharacters(in: .whitespaces)
            guard !v.isEmpty else { return }
            if let c = try? await VenueGeocodingService.geocode(v) {
                await MainActor.run {
                    self.tempCoordinate = c
                    self.previewRegion.center = c                   // ← これを忘れず
                    self.previewRegion.span = .init(latitudeDelta: 0.01, longitudeDelta: 0.01)
                }
            } else {
                await MainActor.run {
                    self.mapInitialQuery = v
                }
            }
        }
    }
}
