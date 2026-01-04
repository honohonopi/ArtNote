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
import UIKit

struct ExhibitionFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @AppStorage("useAIExtraction") private var useAIExtraction = false
    
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
    @State private var hasManuallyEditedDates = false
    @State private var isApplyingAutoDates = false
    @State private var isAIAnalyzing = false
    
    // UI制御
    @State private var showReviewSheet = false
    @State private var showMissingAlert = false
    @State private var missingAlertMessage: String = ""
    
    @State private var pendingAlertMessage: String? = nil
    
    @State private var pickedColor: Color? = nil
    @State private var autoColor: UIColor? = nil
    @State private var posterThumbData: Data? = nil
    
    @State private var mapPickerPayload: MapPickerPayload? = nil
    @State private var tempCoordinate: CLLocationCoordinate2D?
    
    @State private var showCamera = false
    
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
    
    private func handlePickedImage(_ image: UIImage) {
        Task {
            do {
                // ① 画像から情報抽出（設定で AI / OCR を切り替え）
                let result: TextRecognitionService.FlyerExtractionResult
                var usedAI = false
                let shouldUseAI = useAIExtraction
                if shouldUseAI {
                    await MainActor.run { isAIAnalyzing = true }
                }
                if useAIExtraction {
                    do {
                        result = try await TextRecognitionService.extractFlyerFieldsWithAI(from: image)
                        usedAI = true
                    } catch {
                        result = try await TextRecognitionService.extractFlyerFields(from: image)
                    }
                } else {
                    result = try await TextRecognitionService.extractFlyerFields(from: image)
                }

                if let thumb = ImageThumbService.makeThumbnail(image) {
                    await MainActor.run {self.posterThumbData = thumb}
                }
                if let dom = DominantColorService.dominantColor(from: image) {
                    await MainActor.run {
                        self.autoColor = dom
                        self.pickedColor = Color(dom)
                    }
                }

                await MainActor.run {
                    self.titleOptions = result.titleCandidates
                    self.venueOptions = result.venueCandidates
                    self.dateOptions  = result.dateCandidates
                    
                    // フィールドがまだ空なら、一旦一番それっぽい候補を自動で入れておく
                    if self.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                       let firstTitle = result.titleCandidates.first {
                        self.title = firstTitle
                    }
                    
                    if self.venue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                       let firstVenue = result.venueCandidates.first {
                        self.venue = firstVenue
                    }
                    
                    if !self.hasManuallyEditedDates,
                       let firstPeriod = result.dateCandidates.first {
                        self.isApplyingAutoDates = true
                        self.startDate = firstPeriod.0
                        self.endDate   = firstPeriod.1
                        self.isApplyingAutoDates = false
                    }
                    
                    // URL は、もし候補があれば一つだけ入れておく（複数あるケースもあるので適宜）
                    if self.urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                       let firstURL = result.urlCandidates.first {
                        self.urlString = firstURL
                    }
                    
                    // ④ どれかが不足していたら確認シートを出す（今のロジックを転用）
                    let missingTitle = self.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    let missingVenue = self.venue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    let missingDates = self.dateOptions.isEmpty
                    
                    if missingTitle || missingVenue || missingDates {
                        self.showReviewSheet = true
                    }
                    if shouldUseAI {
                        self.isAIAnalyzing = false
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                    }
                }

                if usedAI {
                    if let venuePOI = result.venuePOI, !venuePOI.isEmpty {
                        print("🤖 AI venue_poi: \"\(venuePOI)\"")
                        await autoResolveAddress(from: venuePOI)
                    } else if let firstVenue = result.venueCandidates.first {
                        print("🤖 AI venue candidate: \"\(firstVenue)\"")
                        await autoResolveAddress(from: firstVenue)
                    } else {
                        print("🤖 AI venue candidate: <empty>")
                    }
                }
            } catch {
                // エラー時のアラートは今の実装と同じでOK
                await MainActor.run {
                    if useAIExtraction {
                        self.isAIAnalyzing = false
                    }
                    ocrAlertMessage = "ポスターの文字認識に失敗しました：\(error.localizedDescription)"
                    showOcrAlert = true
                }
            }
        }
    }

    private func autoResolveAddress(from venue: String) async {
        let trimmed = venue.trimmingCharacters(in: .whitespacesAndNewlines)
        print("📍 autoResolveAddress start: \"\(trimmed)\"")
        guard !trimmed.isEmpty else { return }
        guard addressLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("📍 address already filled, skip auto resolve")
            return
        }

        if let result = try? await VenueGeocodingService.geocodeWithAddress(trimmed) {
            await MainActor.run {
                if addressLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                   let addr = result.address, !addr.isEmpty {
                    addressLine = addr
                    print("📍 auto address filled: \"\(addr)\"")
                } else {
                    print("📍 auto address not filled (no addr or already set)")
                }
                if tempCoordinate == nil {
                    tempCoordinate = result.coordinate
                    previewRegion.center = result.coordinate
                    previewRegion.span = .init(latitudeDelta: 0.01, longitudeDelta: 0.01)
                } else {
                    print("📍 coordinate already set, skip update")
                }
            }
        } else {
            print("📍 geocodeWithAddress returned nil")
        }
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
        ex.posterThumbData = posterThumbData
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
    
    var body: some View {
        NavigationStack {
            Form {
                Section("基本情報") {
                    TextField("展覧会名", text: $title)
                        .overlay(alignment: .trailing) {
                            if isAIAnalyzing {
                                ProgressView()
                                    .scaleEffect(0.7)
                            }
                        }
                    TextField("会場", text: $venue)
                        .overlay(alignment: .trailing) {
                            if isAIAnalyzing {
                                ProgressView()
                                    .scaleEffect(0.7)
                            }
                        }
                        .onSubmit {
                            triggerGeocoding()
                        }
                    HStack(spacing: 8) {
                        TextField("会場住所（任意）", text: $addressLine)   // ← 住所用の @State を持っていなければ追加
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                            .overlay(alignment: .trailing) {
                                if isAIAnalyzing {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                }
                            }
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
                        .onChange(of: startDate) { _ in
                            if !isApplyingAutoDates { hasManuallyEditedDates = true }
                        }
                        .overlay(alignment: .trailing) {
                            if isAIAnalyzing {
                                ProgressView()
                                    .scaleEffect(0.7)
                            }
                        }
                    DatePicker("終了日", selection: $endDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .environment(\.locale, Locale(identifier: "ja_JP"))
                        .environment(\.calendar, Calendar(identifier: .gregorian))
                        .onChange(of: endDate) { _ in
                            if !isApplyingAutoDates { hasManuallyEditedDates = true }
                        }
                        .overlay(alignment: .trailing) {
                            if isAIAnalyzing {
                                ProgressView()
                                    .scaleEffect(0.7)
                            }
                        }
                    TextField("公式URL（任意）", text: $urlString)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .overlay(alignment: .trailing) {
                            if isAIAnalyzing {
                                ProgressView()
                                    .scaleEffect(0.7)
                            }
                        }
                }
                Section("ポスターから自動入力") {
                    Menu {
                        Button {
                            showPhotoPicker = true
                        } label: {
                            Label("写真ライブラリから選ぶ", systemImage: "photo.on.rectangle")
                        }

                        if UIImagePickerController.isSourceTypeAvailable(.camera) {
                            Button {
                                showCamera = true
                            } label: {
                                Label("カメラ", systemImage: "camera.viewfinder")
                            }
                        }
                    } label: {
                        // もともとの見た目はそのまま
                        Label("写真から情報を抽出", systemImage: "text.viewfinder")
                    }
                }
                .onChange(of: selectedItem) { _, newItem in
                    guard let item = newItem else { return }
                    Task {
                        if let data = try? await item.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            handlePickedImage(image)
                        } else {
                            await MainActor.run {
                                ocrAlertMessage = "画像の読み込みに失敗しました。"
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
            .navigationTitle("展覧会を追加")
            .navigationBarTitleDisplayMode(.inline)
            .overlay(alignment: .top) {
                if isAIAnalyzing {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.9)
                        Text("ポスターを解析中…")
                            .font(.subheadline)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.top, 0)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
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
                                    isApplyingAutoDates = true
                                    startDate = min(p.0, p.1); endDate = max(p.0, p.1)
                                    isApplyingAutoDates = false
                                    hasManuallyEditedDates = true
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
        .sheet(isPresented: $showCamera) {
            CameraPicker { image in
                if let img = image { handlePickedImage(img) }
                showCamera = false
            }
        }
    }
}
