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
        let ex = Exhibition(title: vm.title,
                            venue: vm.venue,
                            address: vm.addressLine.trimmingCharacters(in: .whitespacesAndNewlines),
                            startDate: vm.startDate,
                            endDate: vm.endDate,
                            url: URL(string: vm.urlString),
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
                    showCamera: $vm.showCamera
                )
                .onChange(of: vm.selectedItem) { _, newItem in
                    guard let item = newItem else { return }
                    Task {
                        if let data = try? await item.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            await vm.handlePickedImage(image, useAIExtraction: useAIExtraction)
                        } else {
                            await MainActor.run {
                                vm.ocrAlertMessage = "画像の読み込みに失敗しました。"
                                vm.showOcrAlert = true
                            }
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
                CatalogSectionView(catalogTotalCountStr: $vm.catalogTotalCountStr)
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
        .photosPicker(isPresented: $vm.showPhotoPicker, selection: $vm.selectedItem, matching: .images)
        .sheet(isPresented: $vm.showCamera) {
            CameraPicker { image in
                if let img = image {
                    Task { await vm.handlePickedImage(img, useAIExtraction: useAIExtraction) }
                }
                vm.showCamera = false
            }
        }
    }
}

private struct PosterAutoInputSectionView: View {
    @Binding var showPhotoPicker: Bool
    @Binding var showCamera: Bool

    var body: some View {
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
                Label("写真から情報を抽出", systemImage: "text.viewfinder")
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
