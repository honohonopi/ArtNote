//
//  ExhibitionFormView.swift
//  ArtNote
//
//  Created by Honoka Nishiyama on 2025/10/03.
//

// 展覧会登録フォーム
import SwiftUI
import Observation
import UniformTypeIdentifiers
@preconcurrency import PDFKit
import SwiftData
import PhotosUI
import CoreLocation
import MapKit
import UIKit

struct ExhibitionFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var writeState = ExhibitionWriteState()

    @State private var vm = ExhibitionFormViewModel()


    // 表示用フォーマッタ
    private var ymdFormatter: DateFormatter {
        let f = DateFormatter.japanese()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "yyyy/MM/dd"
        return f
    }
    
    private func save() {
        let exhibition = vm.makeExhibition()
        writeState.run {
            try await ExhibitionPersistenceService(context: context).insert(exhibition)
            dismiss()
        }
    }
    
    var body: some View {
        @Bindable var draft = vm.draft
        NavigationStack {
            Form {
                PosterAutoInputSectionView(
                    showPhotoPicker: $vm.showPhotoPicker,
                    showCamera: $vm.showCamera,
                    showPDFPicker: $vm.showPDFPicker
                )
                .onChange(of: vm.selectedItems) { _, newItems in
                    guard !newItems.isEmpty else { return }
                    Task { await vm.handleSelectedPhotoItems(newItems) }
                }
                .alert(vm.missingAlertMessage, isPresented: $vm.showMissingAlert) {
                    Button("OK", role: .cancel) {}
                }
                .alert(vm.ocrAlertMessage ?? "", isPresented: $vm.showOcrAlert) {
                    Button("OK", role: .cancel) {}
                }
                .alert("この機能はApple Intelligenceが有効な対応端末で利用できます", isPresented: $vm.showFoundationModelUnavailableAlert) {
                    Button("今後表示しない") {
                        vm.suppressFoundationModelAlert()
                    }
                    Button("OK", role: .cancel) {}
                } message: {
                    Text("Apple Intelligenceをオンにすると、オフラインでもポスター画像から精度の高い情報を抽出できます。\n設定アプリ → Apple Intelligence & Siri → Apple Intelligence をオン\n反映に時間がかかる場合は、アプリを再起動してください。")
                }
                .alert("注意", isPresented: $vm.showFoundationModelDontShowWarning) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text("今後この案内は表示されません。オフライン時の情報抽出の精度が下がる可能性があります。")
                }
                BasicInfoSectionView(
                    title: $draft.title,
                    venue: $draft.venue,
                    addressLine: $draft.addressLine,
                    startDate: $draft.startDate,
                    endDate: $draft.endDate,
                    urlString: $draft.urlString,
                    isAIAnalyzing: vm.isAIAnalyzing,
                    isExtracting: vm.isExtracting,
                    isApplyingAutoDates: draft.isApplyingAutoDates,
                    hasManuallyEditedDates: $draft.hasManuallyEditedDates,
                    onVenueSubmit: draft.triggerGeocoding,
                    onTapMap: draft.prepareMapPicker
                )
                AdmissionInfoSectionView(
                    showAdmissionFees: $draft.showAdmissionFees,
                    admissionFees: $draft.admissionFees,
                    reservationRequired: $draft.reservationRequired,
                    isAIAnalyzing: vm.isAIAnalyzing,
                    admissionPriceText: draft.admissionPriceText,
                    reservationStatusText: draft.reservationStatusText,
                    onAddFee: draft.beginAddingAdmissionFee,
                    onEditFee: draft.beginEditingAdmissionFee
                )
                ScheduleSectionView(isAIAnalyzing: vm.isAIAnalyzing) {
                    ScheduleEditorListView(
                        scheduleOpenTime: $draft.scheduleOpenTime,
                        scheduleCloseTime: $draft.scheduleCloseTime,
                        scheduleLastEntryTime: $draft.scheduleLastEntryTime,
                        scheduleClosedWeekdays: $draft.scheduleClosedWeekdays,
                        scheduleHolidayHandling: $draft.scheduleHolidayHandling,
                        scheduleClosedDateRules: $draft.scheduleClosedDateRules,
                        scheduleOpenDateRules: $draft.scheduleOpenDateRules,
                        scheduleSpecialOpenings: $draft.scheduleSpecialOpenings,
                        onAddSpecialOpening: draft.beginAddingSpecialOpening,
                        onEditSpecialOpening: draft.beginEditingSpecialOpening
                    )
                }
                ColorSelectionSectionView(pickedColor: $draft.pickedColor, autoColor: $draft.autoColor)
            }
            .navigationTitle("展覧会を追加")
            .navigationBarTitleDisplayMode(.inline)
            .overlay(alignment: .top) {
                AIAnalyzingToastView(isVisible: vm.isExtracting)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || draft.venue.isEmpty)
                }
            }
            .exhibitionWriteFeedback(writeState)
            .sheet(isPresented: $vm.showReviewSheet) {
                ExtractionReviewSheetView(
                    titleOptions: vm.titleOptions,
                    venueOptions: vm.venueOptions,
                    dateOptions: vm.dateOptions,
                    urlOptions: vm.urlOptions,
                    showBasicOnlyNotice: vm.showBasicOnlyNotice,
                    selectedTitle: $vm.selectedTitle,
                    selectedVenue: $vm.selectedVenue,
                    selectedDateIndex: $vm.selectedDateIndex,
                    selectedURL: $vm.selectedURL,
                    isApplyingAutoDates: $draft.isApplyingAutoDates,
                    hasManuallyEditedDates: $draft.hasManuallyEditedDates,
                    pendingAlertMessage: $vm.pendingAlertMessage,
                    missingAlertMessage: $vm.missingAlertMessage,
                    showMissingAlert: $vm.showMissingAlert,
                    showReviewSheet: $vm.showReviewSheet,
                    title: $draft.title,
                    venue: $draft.venue,
                    urlString: $draft.urlString,
                    startDate: $draft.startDate,
                    endDate: $draft.endDate,
                    ymdFormatter: ymdFormatter
                )
            }
            .sheet(isPresented: $draft.showSpecialOpeningEditor) {
                SpecialOpeningEditorSheetView(
                    editingSpecialOpeningIndex: $draft.editingSpecialOpeningIndex,
                    showSpecialOpeningEditor: $draft.showSpecialOpeningEditor,
                    specialOpeningMode: $draft.specialOpeningMode,
                    draftSpecialOpeningDate: $draft.draftSpecialOpeningDate,
                    draftSpecialOpeningStartDate: $draft.draftSpecialOpeningStartDate,
                    draftSpecialOpeningEndDate: $draft.draftSpecialOpeningEndDate,
                    draftSpecialOpeningWeekdays: $draft.draftSpecialOpeningWeekdays,
                    draftSpecialOpeningOpenTime: $draft.draftSpecialOpeningOpenTime,
                    draftSpecialOpeningCloseTime: $draft.draftSpecialOpeningCloseTime,
                    draftSpecialOpeningLastEntryTime: $draft.draftSpecialOpeningLastEntryTime,
                    onToggleWeekday: draft.toggleDraftWeekday,
                    onCommit: draft.commitDraftSpecialOpening
                )
            }
            .sheet(isPresented: $draft.showAdmissionFeeEditor) {
                AdmissionFeeEditorSheetView(
                    editingAdmissionFeeIndex: $draft.editingAdmissionFeeIndex,
                    showAdmissionFeeEditor: $draft.showAdmissionFeeEditor,
                    draftAdmissionLabel: $draft.draftAdmissionLabel,
                    draftAdmissionPriceText: $draft.draftAdmissionPriceText,
                    draftAdmissionNote: $draft.draftAdmissionNote,
                    canSaveAdmissionFee: draft.canSaveAdmissionFee,
                    onCommit: draft.commitAdmissionFee
                )
            }
            .sheet(isPresented: $draft.showMapPicker) {
                MapPickerView(seed: draft.tempCoordinate) { pickedCoord, pickedAddress in
                    draft.applyMapSelection(coordinate: pickedCoord, address: pickedAddress)
                }
            }
        }
        .photosPicker(isPresented: $vm.showPhotoPicker, selection: $vm.selectedItems, maxSelectionCount: 2, matching: .images)
        .fullScreenCover(isPresented: $vm.showCamera) {
            CameraPicker { image in
                vm.showCamera = false
                if let image {
                    Task { await vm.handlePickedImage(image) }
                }
            }
        }
        .sheet(item: $vm.pdfSelection) { selection in
            PDFPagePickerSheet(
                url: selection.url,
                pageCount: selection.pageCount,
                onSelect: { indices in
                    vm.pdfSelection = nil
                    Task { await vm.handlePickedPDF(selection.url, pageIndices: indices) }
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
                vm.preparePickedPDF(url)
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
        Section {
            Menu {
                Button {
                    showPDFPicker = true
                } label: {
                    Label("PDFを選ぶ", systemImage: "doc.text")
                }
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
                Label("ポスターを読み込む", systemImage: "text.viewfinder")
            }
        } header: {
            Label("ポスターから展覧会情報を自動入力", systemImage: "sparkles")
        }
    }
}

private struct PDFPagePickerSheet: View {
    let url: URL
    let pageCount: Int
    let onSelect: ([Int]) -> Void
    let onCancel: () -> Void
    @State private var loader: PDFThumbnailLoader
    @State private var selectedIndices: Set<Int>
    @State private var showLimitAlert = false

    init(url: URL, pageCount: Int, onSelect: @escaping ([Int]) -> Void, onCancel: @escaping () -> Void) {
        self.url = url
        self.pageCount = pageCount
        self.onSelect = onSelect
        self.onCancel = onCancel
        _loader = State(initialValue: PDFThumbnailLoader(url: url, pageCount: pageCount))
        _selectedIndices = State(initialValue: pageCount > 0 ? [0] : [])
    }

    var body: some View {
        NavigationStack {
            List {
                Section("読み込むページを選択してください（最大2枚）") {
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
            .alert("ページは2枚まで選択できます。", isPresented: $showLimitAlert) {
                Button("OK", role: .cancel) {}
            }
        }
    }

    private func toggleSelection(_ index: Int) {
        if selectedIndices.contains(index) {
            selectedIndices.remove(index)
        } else {
            if selectedIndices.count >= 2 {
                showLimitAlert = true
            } else {
                selectedIndices.insert(index)
            }
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

@MainActor
@Observable
private final class PDFThumbnailLoader {
    var thumbnails: [Int: UIImage] = [:]
    private let url: URL
    private let pageCount: Int
    private let accessGranted: Bool

    init(url: URL, pageCount: Int) {
        self.url = url
        self.pageCount = pageCount
        accessGranted = url.startAccessingSecurityScopedResource()
    }

    deinit {
        if accessGranted {
            url.stopAccessingSecurityScopedResource()
        }
    }

    func load(page index: Int) {
        guard thumbnails[index] == nil else { return }
        guard index >= 0, index < pageCount else { return }
        let url = url
        let targetSize = CGSize(width: 160, height: 220)
        Task {
            let imageData = await Task.detached(priority: .userInitiated) { () -> Data? in
                guard let document = PDFDocument(url: url),
                      let page = document.page(at: index)
                else { return nil }
                return page.thumbnail(of: targetSize, for: .mediaBox).pngData()
            }.value
            guard let imageData, let image = UIImage(data: imageData) else { return }
            thumbnails[index] = image
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
                Text("抽出中…")
                    .font(.subheadline)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color(red: 163 / 255, green: 212 / 255, blue: 1), in: Capsule())
            .padding(.top, 0)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}


private struct ExtractionReviewSheetView: View {
    let titleOptions: [String]
    let venueOptions: [String]
    let dateOptions: [(Date, Date)]
    let urlOptions: [String]
    let showBasicOnlyNotice: Bool
    @Binding var selectedTitle: String?
    @Binding var selectedVenue: String?
    @Binding var selectedDateIndex: Int
    @Binding var selectedURL: String?
    @Binding var isApplyingAutoDates: Bool
    @Binding var hasManuallyEditedDates: Bool
    @Binding var pendingAlertMessage: String?
    @Binding var missingAlertMessage: String
    @Binding var showMissingAlert: Bool
    @Binding var showReviewSheet: Bool
    @Binding var title: String
    @Binding var venue: String
    @Binding var urlString: String
    @Binding var startDate: Date
    @Binding var endDate: Date
    let ymdFormatter: DateFormatter

    var body: some View {
        NavigationStack {
            Form {
                if showBasicOnlyNotice {
                    Section {
                        Text("高精度の自動抽出が利用できなかったため、基本情報のみ反映しています。入館情報や開館情報は反映されません。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
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
                            let label = dateRangeLabel(pair)
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
                if !urlOptions.isEmpty {
                    Section("公式URL（候補）") {
                        ForEach(urlOptions, id: \.self) { u in
                            HStack {
                                Text(u)
                                    .lineLimit(2)
                                Spacer()
                                if selectedURL == u { Image(systemName: "checkmark") }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture { selectedURL = u }
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
                        if let u = selectedURL { urlString = u }
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

    private func dateRangeLabel(_ pair: (Date, Date)) -> String {
        let start = min(pair.0, pair.1)
        let end = max(pair.0, pair.1)
        return "\(ymdFormatter.string(from: start)) 〜 \(ymdFormatter.string(from: end))"
    }
}
