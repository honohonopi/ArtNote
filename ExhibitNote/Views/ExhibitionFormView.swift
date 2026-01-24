//
//  ExhibitionFormView.swift
//  ArtNote
//
//  Created by Honoka Nishiyama on 2025/10/03.
//

// 展覧会登録フォーム
import SwiftUI
import UniformTypeIdentifiers
import PDFKit
import SwiftData
import PhotosUI
import CoreLocation
import MapKit
import UIKit

struct ExhibitionFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @AppStorage("useAIExtraction") private var useAIExtraction = false

    @StateObject private var vm = ExhibitionFormViewModel()


    // 表示用フォーマッタ
    private var ymdFormatter: DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "yyyy/MM/dd"
        return f
    }
    
    private func save() {
        print(vm.addressLine.trimmingCharacters(in: .whitespacesAndNewlines))
        let total = Int(vm.catalogTotalCountStr.trimmingCharacters(in: .whitespacesAndNewlines))
        let normalizedURL = vm.urlString.normalizedWebURL()
        let ex = Exhibition(title: vm.title,
                            venue: vm.venue,
                            address: vm.addressLine.trimmingCharacters(in: .whitespacesAndNewlines),
                            startDate: vm.startDate,
                            endDate: vm.endDate,
                            url: normalizedURL,
                            catalogTotalCount: total)
        ex.scheduleOpenTime = vm.scheduleOpenTime
        ex.scheduleCloseTime = vm.scheduleCloseTime
        ex.scheduleLastEntryTime = vm.scheduleLastEntryTime
        ex.scheduleClosedWeekdays = vm.scheduleClosedWeekdays.map { $0.rawValue }
        ex.scheduleHolidayHandling = vm.scheduleHolidayHandling.map { holidayHandlingRaw($0) }
        ex.scheduleClosedDateRules = vm.scheduleClosedDateRules.map { $0.toRecord() }
        ex.scheduleOpenDateRules = vm.scheduleOpenDateRules.map { $0.toRecord() }
        ex.scheduleSpecialOpenings = vm.scheduleSpecialOpenings.map { $0.toRecord() }
        ex.admissionFeeRules = vm.admissionFees
        ex.reservationRequired = vm.reservationRequired
        ex.posterThumbData = vm.posterThumbData
        if let c = vm.tempCoordinate {
            ex.setCoordinate(c)
        }
        if let ui = (vm.pickedColor.map { UIColor($0) } ?? vm.autoColor) {
            ex.setColor(ui)
        }
        
        context.insert(ex)
        Task { await ReminderService.shared.scheduleDeadlineNotifications(for: ex) }
        dismiss()
    }
    
    private var hasScheduleInfo: Bool {
        vm.scheduleOpenTime != nil ||
        vm.scheduleCloseTime != nil ||
        vm.scheduleLastEntryTime != nil ||
        !vm.scheduleClosedWeekdays.isEmpty ||
        vm.scheduleHolidayHandling != nil ||
        !vm.scheduleClosedDateRules.isEmpty ||
        !vm.scheduleOpenDateRules.isEmpty ||
        !vm.scheduleSpecialOpenings.isEmpty
    }
    
    private func holidayHandlingRaw(_ value: HolidayHandling) -> String {
        switch value {
        case .none:
            return "NONE"
        case .openOnHoliday:
            return "OPEN_ON_HOLIDAY"
        case .openOnHolidayCloseNextWeekday:
            return "OPEN_ON_HOLIDAY_CLOSE_NEXT_WEEKDAY"
        }
    }

    private func reservationStatusText(_ value: Bool?) -> String {
        switch value {
        case .some(true):
            return "事前予約制"
        case .some(false):
            return "予約不要"
        case .none:
            return "記載なし"
        }
    }
    
    private func admissionPriceText(_ fee: AdmissionFeeRule) -> String? {
        if fee.isFreeLike {
            return "無料"
        }
        if let price = fee.priceYen {
            return "\(price)円"
        }
        return nil
    }


    var body: some View {
        NavigationStack {
            Form {
                BasicInfoSectionView(
                    title: $vm.title,
                    venue: $vm.venue,
                    addressLine: $vm.addressLine,
                    startDate: $vm.startDate,
                    endDate: $vm.endDate,
                    urlString: $vm.urlString,
                    isAIAnalyzing: vm.isAIAnalyzing,
                    isApplyingAutoDates: vm.isApplyingAutoDates,
                    hasManuallyEditedDates: $vm.hasManuallyEditedDates,
                    onVenueSubmit: vm.triggerGeocoding,
                    onTapMap: {
                        let q = vm.addressLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? vm.venue.trimmingCharacters(in: .whitespacesAndNewlines)
                        : vm.addressLine.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !q.isEmpty else { return }
                        vm.mapPickerPayload = ExhibitionFormViewModel.MapPickerPayload(query: q)
                    }
                )
                AdmissionInfoSectionView(
                    showAdmissionFees: $vm.showAdmissionFees,
                    admissionFees: $vm.admissionFees,
                    reservationRequired: $vm.reservationRequired,
                    isAIAnalyzing: vm.isAIAnalyzing,
                    admissionPriceText: admissionPriceText,
                    reservationStatusText: reservationStatusText,
                    onAddFee: {
                        vm.editingAdmissionFeeIndex = nil
                        vm.prepareAdmissionFeeEditor()
                        vm.showAdmissionFeeEditor = true
                    },
                    onEditFee: { idx in
                        vm.editingAdmissionFeeIndex = idx
                        vm.prepareAdmissionFeeEditor(for: vm.admissionFees[idx])
                        vm.showAdmissionFeeEditor = true
                    }
                )
                ScheduleSectionView(isAIAnalyzing: vm.isAIAnalyzing) {
                    ScheduleEditorListView(
                        scheduleOpenTime: $vm.scheduleOpenTime,
                        scheduleCloseTime: $vm.scheduleCloseTime,
                        scheduleLastEntryTime: $vm.scheduleLastEntryTime,
                        scheduleClosedWeekdays: $vm.scheduleClosedWeekdays,
                        scheduleHolidayHandling: $vm.scheduleHolidayHandling,
                        scheduleClosedDateRules: $vm.scheduleClosedDateRules,
                        scheduleOpenDateRules: $vm.scheduleOpenDateRules,
                        scheduleSpecialOpenings: $vm.scheduleSpecialOpenings,
                        onAddSpecialOpening: {
                            vm.editingSpecialOpeningIndex = nil
                            vm.prepareSpecialOpeningEditor()
                            vm.showSpecialOpeningEditor = true
                        },
                        onEditSpecialOpening: { idx in
                            vm.editingSpecialOpeningIndex = idx
                            vm.prepareSpecialOpeningEditor(for: vm.scheduleSpecialOpenings[idx])
                            vm.showSpecialOpeningEditor = true
                        }
                    )
                }
                PosterAutoInputSectionView(
                    showPhotoPicker: $vm.showPhotoPicker,
                    showCamera: $vm.showCamera,
                    showPDFPicker: $vm.showPDFPicker
                )
                .onChange(of: vm.selectedItems) { _, newItems in
                    guard !newItems.isEmpty else { return }
                    Task {
                        let limited = Array(newItems.prefix(2))
                        var images: [UIImage] = []
                        for item in limited {
                            if let data = try? await item.loadTransferable(type: Data.self),
                               let image = UIImage(data: data) {
                                images.append(image)
                            }
                        }
                        if images.isEmpty {
                            await MainActor.run {
                                vm.ocrAlertMessage = "画像の読み込みに失敗しました。"
                                vm.showOcrAlert = true
                                vm.selectedItems = []
                            }
                            return
                        }
                        await vm.handlePickedImages(images, useAIExtraction: useAIExtraction)
                        await MainActor.run {
                            vm.selectedItems = []
                        }
                    }
                }
                .alert(vm.missingAlertMessage, isPresented: $vm.showMissingAlert) {
                    Button("OK", role: .cancel) {}
                }
                .alert(vm.ocrAlertMessage ?? "", isPresented: $vm.showOcrAlert) {
                    Button("OK", role: .cancel) {}
                }
                ColorSelectionSectionView(pickedColor: $vm.pickedColor, autoColor: $vm.autoColor)
            }
            .navigationTitle("展覧会を追加")
            .navigationBarTitleDisplayMode(.inline)
            .overlay(alignment: .top) {
                AIAnalyzingToastView(isVisible: vm.isAIAnalyzing)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(vm.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.venue.isEmpty)
                }
            }
            .sheet(isPresented: $vm.showReviewSheet) {
                ExtractionReviewSheetView(
                    titleOptions: vm.titleOptions,
                    venueOptions: vm.venueOptions,
                    dateOptions: vm.dateOptions,
                    selectedTitle: $vm.selectedTitle,
                    selectedVenue: $vm.selectedVenue,
                    selectedDateIndex: $vm.selectedDateIndex,
                    isApplyingAutoDates: $vm.isApplyingAutoDates,
                    hasManuallyEditedDates: $vm.hasManuallyEditedDates,
                    pendingAlertMessage: $vm.pendingAlertMessage,
                    missingAlertMessage: $vm.missingAlertMessage,
                    showMissingAlert: $vm.showMissingAlert,
                    showReviewSheet: $vm.showReviewSheet,
                    title: $vm.title,
                    venue: $vm.venue,
                    startDate: $vm.startDate,
                    endDate: $vm.endDate,
                    ymdFormatter: ymdFormatter
                )
            }
            .sheet(isPresented: $vm.showSpecialOpeningEditor) {
                SpecialOpeningEditorSheetView(
                    editingSpecialOpeningIndex: $vm.editingSpecialOpeningIndex,
                    showSpecialOpeningEditor: $vm.showSpecialOpeningEditor,
                    specialOpeningMode: $vm.specialOpeningMode,
                    draftSpecialOpeningDate: $vm.draftSpecialOpeningDate,
                    draftSpecialOpeningStartDate: $vm.draftSpecialOpeningStartDate,
                    draftSpecialOpeningEndDate: $vm.draftSpecialOpeningEndDate,
                    draftSpecialOpeningWeekdays: $vm.draftSpecialOpeningWeekdays,
                    draftSpecialOpeningOpenTime: $vm.draftSpecialOpeningOpenTime,
                    draftSpecialOpeningCloseTime: $vm.draftSpecialOpeningCloseTime,
                    draftSpecialOpeningLastEntryTime: $vm.draftSpecialOpeningLastEntryTime,
                    onToggleWeekday: vm.toggleDraftWeekday,
                    onCommit: vm.commitDraftSpecialOpening
                )
            }
            .sheet(isPresented: $vm.showAdmissionFeeEditor) {
                AdmissionFeeEditorSheetView(
                    editingAdmissionFeeIndex: $vm.editingAdmissionFeeIndex,
                    showAdmissionFeeEditor: $vm.showAdmissionFeeEditor,
                    draftAdmissionLabel: $vm.draftAdmissionLabel,
                    draftAdmissionPriceText: $vm.draftAdmissionPriceText,
                    draftAdmissionNote: $vm.draftAdmissionNote,
                    canSaveAdmissionFee: vm.canSaveAdmissionFee,
                    onCommit: vm.commitAdmissionFee
                )
            }
            .sheet(item: $vm.mapPickerPayload) { payload in
                NavigationStack {
                    MapPickerView(seed: vm.tempCoordinate, initialQuery: payload.query) { pickedCoord, pickedAddress in
                        // 座標を反映
                        vm.tempCoordinate = pickedCoord
                        vm.previewRegion.center = pickedCoord
                        vm.previewRegion.span = .init(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        // 住所を反映（未入力なら反映／常に上書き、好みで）
                        if let addr = pickedAddress, !addr.isEmpty {
                            if vm.addressLine.isEmpty {
                                vm.addressLine = addr
                            } else {
                            }
                        }
                    }
                }
            }
        }
        .photosPicker(isPresented: $vm.showPhotoPicker, selection: $vm.selectedItems, maxSelectionCount: 2, matching: .images)
        .sheet(isPresented: $vm.showCamera) {
            CameraPicker { image in
                if let img = image {
                    Task { await vm.handlePickedImage(img, useAIExtraction: useAIExtraction) }
                }
                vm.showCamera = false
            }
        }
        .sheet(item: $vm.pdfSelection) { selection in
            PDFPagePickerSheet(
                url: selection.url,
                pageCount: selection.pageCount,
                onSelect: { indices in
                    vm.pdfSelection = nil
                    Task { await vm.handlePickedPDF(selection.url, pageIndices: indices, useAIExtraction: selection.useAIExtraction) }
                },
                onCancel: {
                    vm.pdfSelection = nil
                }
            )
        }
        .fileImporter(isPresented: $vm.showPDFPicker, allowedContentTypes: [.pdf], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                vm.preparePickedPDF(url, useAIExtraction: useAIExtraction)
            case .failure:
                vm.ocrAlertMessage = "PDFの読み込みに失敗しました。"
                vm.showOcrAlert = true
            }
        }
    }
}

private struct PosterAutoInputSectionView: View {
    @Binding var showPhotoPicker: Bool
    @Binding var showCamera: Bool
    @Binding var showPDFPicker: Bool

    var body: some View {
        Section("ポスターから展覧会情報を自動入力") {
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
                Button {
                    showPDFPicker = true
                } label: {
                    Label("PDFを選ぶ", systemImage: "doc.text")
                }
            } label: {
                Label("ポスターを読み込む", systemImage: "text.viewfinder")
            }
        }
    }
}

private struct PDFPagePickerSheet: View {
    let url: URL
    let pageCount: Int
    let onSelect: ([Int]) -> Void
    let onCancel: () -> Void
    @StateObject private var loader: PDFThumbnailLoader
    @State private var selectedIndices: Set<Int>

    init(url: URL, pageCount: Int, onSelect: @escaping ([Int]) -> Void, onCancel: @escaping () -> Void) {
        self.url = url
        self.pageCount = pageCount
        self.onSelect = onSelect
        self.onCancel = onCancel
        _loader = StateObject(wrappedValue: PDFThumbnailLoader(url: url, pageCount: pageCount))
        _selectedIndices = State(initialValue: pageCount > 0 ? [0] : [])
    }

    var body: some View {
        NavigationStack {
            List {
                Section("読み込むページを選択してください") {
                    ForEach(0..<pageCount, id: \.self) { index in
                        Button {
                            toggleSelection(index)
                        } label: {
                            HStack(spacing: 12) {
                                PDFPageThumbnailView(image: loader.thumbnails[index])
                                    .frame(width: 64, height: 90)
                                Text("ページ \(index + 1)")
                                    .foregroundColor(.primary)
                                Spacer()
                                if selectedIndices.contains(index) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                        .onAppear { loader.load(page: index) }
                    }
                }
            }
            .navigationTitle("PDFページ選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") {
                        onSelect(selectedIndices.sorted())
                    }
                    .disabled(selectedIndices.isEmpty)
                }
            }
        }
    }

    private func toggleSelection(_ index: Int) {
        if selectedIndices.contains(index) {
            selectedIndices.remove(index)
        } else {
            selectedIndices.insert(index)
        }
    }
}

private struct PDFPageThumbnailView: View {
    let image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.1))
                    ProgressView()
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private final class PDFThumbnailLoader: ObservableObject {
    @Published var thumbnails: [Int: UIImage] = [:]
    private let url: URL
    private let pageCount: Int
    private let accessGranted: Bool
    private let document: PDFDocument?

    init(url: URL, pageCount: Int) {
        self.url = url
        self.pageCount = pageCount
        accessGranted = url.startAccessingSecurityScopedResource()
        document = PDFDocument(url: url)
    }

    deinit {
        if accessGranted {
            url.stopAccessingSecurityScopedResource()
        }
    }

    func load(page index: Int) {
        guard thumbnails[index] == nil else { return }
        guard index >= 0, index < pageCount else { return }
        guard let page = document?.page(at: index) else { return }
        let targetSize = CGSize(width: 160, height: 220)
        DispatchQueue.global(qos: .userInitiated).async {
            let image = page.thumbnail(of: targetSize, for: .mediaBox)
            DispatchQueue.main.async {
                self.thumbnails[index] = image
            }
        }
    }
}

private struct AIAnalyzingToastView: View {
    let isVisible: Bool

    var body: some View {
        if isVisible {
            HStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.9)
                Text("ポスターを解析中…")
                    .font(.subheadline)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color.blue.opacity(0.2), in: Capsule())
            .padding(.top, 0)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}


private struct ExtractionReviewSheetView: View {
    let titleOptions: [String]
    let venueOptions: [String]
    let dateOptions: [(Date, Date)]
    @Binding var selectedTitle: String?
    @Binding var selectedVenue: String?
    @Binding var selectedDateIndex: Int
    @Binding var isApplyingAutoDates: Bool
    @Binding var hasManuallyEditedDates: Bool
    @Binding var pendingAlertMessage: String?
    @Binding var missingAlertMessage: String
    @Binding var showMissingAlert: Bool
    @Binding var showReviewSheet: Bool
    @Binding var title: String
    @Binding var venue: String
    @Binding var startDate: Date
    @Binding var endDate: Date
    let ymdFormatter: DateFormatter

    var body: some View {
        NavigationStack {
            Form {
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
