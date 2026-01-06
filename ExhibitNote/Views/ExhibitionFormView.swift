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
    
    private func scheduleClosedWeekdaysText() -> String {
        let map: [Weekday: String] = [
            .monday: "月",
            .tuesday: "火",
            .wednesday: "水",
            .thursday: "木",
            .friday: "金",
            .saturday: "土",
            .sunday: "日"
        ]
        let labels = vm.scheduleClosedWeekdays.compactMap { map[$0] }
        return labels.joined(separator: "・")
    }
    
    private func holidayHandlingText(_ value: HolidayHandling?) -> String {
        guard let value else { return "記載なし" }
        switch value {
        case .none:
            return "祝日対応なし"
        case .openOnHoliday:
            return "祝日は開館"
        case .openOnHolidayCloseNextWeekday:
            return "祝日開館・翌平日休館"
        }
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
    
    private func dateListText(_ dates: [Date]) -> String {
        let sorted = dates.sorted()
        return sorted.map { $0.ymdString }.joined(separator: " / ")
    }
    
    private func specialOpeningsText(_ openings: [SpecialOpening]) -> String {
        let sorted = openings.sorted { left, right in
            switch (left.rule, right.rule) {
            case (.date(let l), .date(let r)):
                return l < r
            case (.date, .range):
                return true
            case (.date, .weekday):
                return true
            case (.range, .date):
                return false
            case (.range(let lStart, _), .range(let rStart, _)):
                return lStart < rStart
            case (.range, .weekday):
                return true
            case (.weekday, .date):
                return false
            case (.weekday, .range):
                return false
            case (.weekday(let l), .weekday(let r)):
                return l.rawValue < r.rawValue
            }
        }
        return sorted.map { entry in
            let base: String
            switch entry.rule {
            case .date(let date):
                base = "\(date.ymdString) \(entry.openTime)–\(entry.closeTime)"
            case .weekday(let weekday):
                base = "\(weeklyLabel(weekday)) \(entry.openTime)–\(entry.closeTime)"
            case .range(let start, let end):
                base = "\(start.ymdString)〜\(end.ymdString) \(entry.openTime)–\(entry.closeTime)"
            }
            var text = base
            if let last = entry.lastEntryTime, !last.isEmpty {
                text += "（最終入場 \(last)）"
            }
            if let note = entry.note?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
                text += " \(note)"
            }
            return text
        }
        .joined(separator: " / ")
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


    private var scheduleList: some View {
        Group {
            HStack {
                Text("開館時間")
                Spacer()
                HStack(spacing: 4) {
                    DatePicker("", selection: timeBindingOptional($vm.scheduleOpenTime, defaultTime: "10:00"), displayedComponents: .hourAndMinute)
                        .labelsHidden()
                    Text("〜")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 16)
                    DatePicker("", selection: timeBindingOptional($vm.scheduleCloseTime, defaultTime: "17:00"), displayedComponents: .hourAndMinute)
                        .labelsHidden()
                }
            }
            HStack {
                Text("最終入場")
                Spacer()
                if vm.scheduleLastEntryTime != nil {
                    HStack(spacing: 8) {
                        DatePicker("", selection: timeBindingOptional($vm.scheduleLastEntryTime, defaultTime: vm.scheduleCloseTime ?? "17:00"), displayedComponents: .hourAndMinute)
                            .labelsHidden()
                        Button {
                            vm.scheduleLastEntryTime = nil
                        } label: {
                            Image(systemName: "minus.circle")
                                .foregroundStyle(.red)
                        }
                    }
                } else {
                    HStack(spacing: 6) {
                        Text("未設定")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Button {
                            vm.scheduleLastEntryTime = vm.scheduleCloseTime ?? "17:00"
                        } label: {
                            Image(systemName: "plus.circle")
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            HStack {
                Text("休館曜日")
                Spacer()
                HStack(spacing: 6) {
                    ForEach(Weekday.allCases, id: \.self) { day in
                        let selected = vm.scheduleClosedWeekdays.contains(day)
                        Button(weekdayShortLabel(day)) {
                            toggleWeekday(day)
                        }
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(selected ? Color.blue.opacity(0.2) : Color(.systemGray5))
                        .clipShape(Capsule())
                        .buttonStyle(.plain)
                    }
                }
            }
            HStack {
                Text("祝日対応")
                Spacer()
                Menu {
                    Button("記載なし") { vm.scheduleHolidayHandling = nil }
                    Button("祝日対応なし") { vm.scheduleHolidayHandling = .none }
                    Button("祝日は開館") { vm.scheduleHolidayHandling = .openOnHoliday }
                    Button("祝日開館、翌平日休館") { vm.scheduleHolidayHandling = .openOnHolidayCloseNextWeekday }
                } label: {
                    HStack(spacing: 6) {
                        Text(holidayHandlingText(vm.scheduleHolidayHandling))
                            .foregroundStyle(.black)
                        Image(systemName: "chevron.up.chevron.down")
                            .foregroundStyle(.blue)
                            .font(.caption)
                    }
                }
            }
            HStack {
                Text("特別休館日")
                Spacer()
                Menu {
                    Button("単日") {
                        vm.scheduleClosedDateRules.append(DateRule(rule: .date(Date()), note: nil))
                    }
                    Button("期間") {
                        let start = Date()
                        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
                        vm.scheduleClosedDateRules.append(DateRule(rule: .range(start: start, end: end), note: nil))
                    }
                } label: {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(.blue)
                }
            }
            ForEach(vm.scheduleClosedDateRules.indices, id: \.self) { idx in
                HStack {
                    Spacer()
                    switch vm.scheduleClosedDateRules[idx].rule {
                    case .date(let date):
                        DatePicker("", selection: Binding(
                            get: { date },
                            set: { newDate in
                                vm.scheduleClosedDateRules[idx].rule = .date(newDate)
                            }
                        ), displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                    case .range(let start, let end):
                        DatePicker("", selection: Binding(
                            get: { start },
                            set: { newStart in
                                vm.scheduleClosedDateRules[idx].rule = .range(start: newStart, end: end)
                            }
                        ), displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                        Text("〜")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        DatePicker("", selection: Binding(
                            get: { end },
                            set: { newEnd in
                                vm.scheduleClosedDateRules[idx].rule = .range(start: start, end: newEnd)
                            }
                        ), displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                    }
                    Button {
                        vm.scheduleClosedDateRules.remove(at: idx)
                    } label: {
                        Image(systemName: "minus.circle")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
                .environment(\.locale, Locale(identifier: "ja_JP"))
                .environment(\.calendar, Calendar(identifier: .gregorian))
            }
            HStack {
                Text("特別開館日")
                Spacer()
                Button {
                    vm.scheduleOpenDateRules.append(DateRule(rule: .date(Date()), note: nil))
                } label: {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(.blue)
                }
            }
            ForEach(vm.scheduleOpenDateRules.indices, id: \.self) { idx in
                HStack {
                    Spacer()
                    DatePicker("", selection: Binding(
                        get: {
                            if case .date(let date) = vm.scheduleOpenDateRules[idx].rule {
                                return date
                            }
                            return Date()
                        },
                        set: { newDate in
                            vm.scheduleOpenDateRules[idx].rule = .date(newDate)
                        }
                    ), displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    Button {
                        vm.scheduleOpenDateRules.remove(at: idx)
                    } label: {
                        Image(systemName: "minus.circle")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
                .environment(\.locale, Locale(identifier: "ja_JP"))
                .environment(\.calendar, Calendar(identifier: .gregorian))
            }
            HStack {
                Text("特別開館時間")
                Spacer()
                Button {
                    vm.editingSpecialOpeningIndex = nil
                    vm.prepareSpecialOpeningEditor()
                    vm.showSpecialOpeningEditor = true
                } label: {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }
            ForEach(vm.scheduleSpecialOpenings.indices, id: \.self) { idx in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(specialOpeningLabel(vm.scheduleSpecialOpenings[idx]))
                            .foregroundStyle(.primary)
                        Spacer()
                        Text("\(vm.scheduleSpecialOpenings[idx].openTime)〜\(vm.scheduleSpecialOpenings[idx].closeTime)")
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                        Menu {
                            Button("編集") {
                                vm.editingSpecialOpeningIndex = idx
                                vm.prepareSpecialOpeningEditor(for: vm.scheduleSpecialOpenings[idx])
                                vm.showSpecialOpeningEditor = true
                            }
                            Button("削除", role: .destructive) {
                                vm.scheduleSpecialOpenings.remove(at: idx)
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .foregroundStyle(.blue)
                        }
                    }
                    if let last = vm.scheduleSpecialOpenings[idx].lastEntryTime, !last.isEmpty {
                        Text("最終入場 \(last)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func specialOpeningLabel(_ opening: SpecialOpening) -> String {
        switch opening.rule {
        case .date(let date):
            return date.ymdString
        case .weekday(let weekday):
            return weekdayLabel(weekday)
        case .range(let start, let end):
            return "\(start.ymdString)〜\(end.ymdString)"
        }
    }

    private func weekdayLabel(_ weekday: Weekday) -> String {
        switch weekday {
        case .monday: return "月曜日"
        case .tuesday: return "火曜日"
        case .wednesday: return "水曜日"
        case .thursday: return "木曜日"
        case .friday: return "金曜日"
        case .saturday: return "土曜日"
        case .sunday: return "日曜日"
        }
    }

    private func weekdayShortLabel(_ weekday: Weekday) -> String {
        switch weekday {
        case .monday: return "月"
        case .tuesday: return "火"
        case .wednesday: return "水"
        case .thursday: return "木"
        case .friday: return "金"
        case .saturday: return "土"
        case .sunday: return "日"
        }
    }

    private func toggleWeekday(_ weekday: Weekday) {
        if let idx = vm.scheduleClosedWeekdays.firstIndex(of: weekday) {
            vm.scheduleClosedWeekdays.remove(at: idx)
        } else {
            vm.scheduleClosedWeekdays.append(weekday)
            vm.scheduleClosedWeekdays.sort { $0.calendarValue < $1.calendarValue }
        }
    }

    private func timeBindingOptional(_ value: Binding<String?>, defaultTime: String) -> Binding<Date> {
        Binding<Date>(
            get: {
                timeDate(from: value.wrappedValue) ?? timeDate(from: defaultTime) ?? Date()
            },
            set: { newDate in
                value.wrappedValue = timeString(from: newDate)
            }
        )
    }

    private func timeBinding(_ value: Binding<String>, defaultTime: String) -> Binding<Date> {
        Binding<Date>(
            get: {
                timeDate(from: value.wrappedValue) ?? timeDate(from: defaultTime) ?? Date()
            },
            set: { newDate in
                value.wrappedValue = timeString(from: newDate)
            }
        )
    }

    private func timeDate(from text: String?) -> Date? {
        guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter.date(from: text)
    }

    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func weeklyLabel(_ weekday: Weekday) -> String {
        switch weekday {
        case .monday: return "毎週月曜"
        case .tuesday: return "毎週火曜"
        case .wednesday: return "毎週水曜"
        case .thursday: return "毎週木曜"
        case .friday: return "毎週金曜"
        case .saturday: return "毎週土曜"
        case .sunday: return "毎週日曜"
        }
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
                    scheduleList
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

private struct AdmissionInfoSectionView: View {
    @Binding var showAdmissionFees: Bool
    @Binding var admissionFees: [AdmissionFeeRule]
    @Binding var reservationRequired: Bool?

    let isAIAnalyzing: Bool
    let admissionPriceText: (AdmissionFeeRule) -> String?
    let reservationStatusText: (Bool?) -> String
    let onAddFee: () -> Void
    let onEditFee: (Int) -> Void

    private var displayAdmissionFeeIndices: [Int] {
        admissionFees.indices.filter { idx in
            let fee = admissionFees[idx]
            return fee.priceYen != nil ||
                (fee.note?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
        }
    }

    var body: some View {
        Section("入館情報") {
            DisclosureGroup(isExpanded: $showAdmissionFees) {
                Button(action: onAddFee) {
                    HStack {
                        Image(systemName: "plus.circle")
                            .foregroundStyle(.blue)
                        Text("入館料を追加")
                            .foregroundStyle(.blue)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
                ForEach(displayAdmissionFeeIndices, id: \.self) { idx in
                    let fee = admissionFees[idx]
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(fee.rawLabel)
                            Spacer()
                            if let priceText = admissionPriceText(fee) {
                                Text(priceText)
                                    .foregroundStyle(.primary)
                            }
                            Menu {
                                Button("編集") { onEditFee(idx) }
                                Button("削除", role: .destructive) {
                                    admissionFees.remove(at: idx)
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .foregroundStyle(.blue)
                            }
                        }
                        if let note = fee.note?.trimmingCharacters(in: .whitespacesAndNewlines),
                           !note.isEmpty {
                            Text(note)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "yensign.circle")
                        .foregroundStyle(.secondary)
                    Text("入館料")
                        .foregroundStyle(.primary)
                    Spacer()
                    if isAIAnalyzing {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                }
            }
            .animation(.easeInOut(duration: 0.2), value: showAdmissionFees)
            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
                Text("予約情報")
                    .foregroundStyle(.primary)
                Spacer()
                Menu {
                    Button("記載なし") { reservationRequired = nil }
                    Button("予約不要") { reservationRequired = false }
                    Button("事前予約制") { reservationRequired = true }
                } label: {
                    HStack(spacing: 6) {
                        Text(reservationStatusText(reservationRequired))
                            .foregroundStyle(.black)
                        Image(systemName: "chevron.up.chevron.down")
                            .foregroundStyle(.blue)
                            .font(.caption)
                    }
                }
                if isAIAnalyzing {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
        }
    }
}

private struct BasicInfoSectionView: View {
    @Binding var title: String
    @Binding var venue: String
    @Binding var addressLine: String
    @Binding var startDate: Date
    @Binding var endDate: Date
    @Binding var urlString: String
    let isAIAnalyzing: Bool
    let isApplyingAutoDates: Bool
    @Binding var hasManuallyEditedDates: Bool
    let onVenueSubmit: () -> Void
    let onTapMap: () -> Void

    var body: some View {
        Section("基本情報") {
            HStack(spacing: 8) {
                Image(systemName: "a.square")
                    .foregroundStyle(.secondary)
                TextField("展覧会名", text: $title)
                    .overlay(alignment: .trailing) {
                        if isAIAnalyzing {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                    }
            }
            HStack(spacing: 8) {
                Image(systemName: "building.columns")
                    .foregroundStyle(.secondary)
                TextField("会場", text: $venue)
                    .overlay(alignment: .trailing) {
                        if isAIAnalyzing {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                    }
                    .onSubmit(onVenueSubmit)
            }
            HStack(spacing: 8) {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundStyle(.secondary)
                TextField("会場住所（任意）", text: $addressLine)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .overlay(alignment: .trailing) {
                        if isAIAnalyzing {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                    }
                Button(action: onTapMap) {
                    Image(systemName: "map")
                        .imageScale(.large)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("地図で位置を選ぶ")
            }
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .foregroundStyle(.secondary)
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
            }
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .foregroundStyle(.secondary)
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
            }
            HStack(spacing: 8) {
                Image(systemName: "link")
                    .foregroundStyle(.secondary)
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

private struct ColorSelectionSectionView: View {
    @Binding var pickedColor: Color?
    @Binding var autoColor: UIColor?

    var body: some View {
        Section("色を選択") {
            HStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(pickedColor ?? (autoColor.map { Color($0) } ?? Color.blue))
                    .frame(width: 24, height: 24)

                ColorPicker(
                    "帯の色",
                    selection: Binding(
                        get: { pickedColor ?? (autoColor.map { Color($0) } ?? .blue) },
                        set: { pickedColor = $0 }
                    ),
                    supportsOpacity: false
                )
            }
        }
    }
}

private struct CatalogSectionView: View {
    @Binding var catalogTotalCountStr: String

    var body: some View {
        Section("目録") {
            TextField("目録総数（例: 80）", text: $catalogTotalCountStr)
                .keyboardType(.numberPad)
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

private struct ScheduleSectionView<Content: View>: View {
    let isAIAnalyzing: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        Section("開館情報") {
            DisclosureGroup {
                content()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundStyle(.secondary)
                    Text("開館情報")
                        .foregroundStyle(.primary)
                    Spacer()
                    if isAIAnalyzing {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                }
            }
        }
    }
}

private struct SpecialOpeningEditorSheetView: View {
    @Binding var editingSpecialOpeningIndex: Int?
    @Binding var showSpecialOpeningEditor: Bool
    @Binding var specialOpeningMode: SpecialOpeningInputMode
    @Binding var draftSpecialOpeningDate: Date
    @Binding var draftSpecialOpeningStartDate: Date
    @Binding var draftSpecialOpeningEndDate: Date
    @Binding var draftSpecialOpeningWeekdays: Set<Weekday>
    @Binding var draftSpecialOpeningOpenTime: String
    @Binding var draftSpecialOpeningCloseTime: String
    @Binding var draftSpecialOpeningLastEntryTime: String?
    let onToggleWeekday: (Weekday) -> Void
    let onCommit: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("種別") {
                    Picker("種別", selection: $specialOpeningMode) {
                        ForEach(SpecialOpeningInputMode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Section("対象") {
                    switch specialOpeningMode {
                    case .date:
                        DatePicker("日付", selection: $draftSpecialOpeningDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                    case .weekday:
                        HStack(spacing: 6) {
                            ForEach(Weekday.allCases, id: \.self) { day in
                                let selected = draftSpecialOpeningWeekdays.contains(day)
                                Button(weekdayShortLabel(day)) {
                                    onToggleWeekday(day)
                                }
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                                .background(selected ? Color.blue.opacity(0.2) : Color(.systemGray5))
                                .clipShape(Capsule())
                                .buttonStyle(.plain)
                            }
                        }
                    case .range:
                        DatePicker("開始日", selection: $draftSpecialOpeningStartDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                        DatePicker("終了日", selection: $draftSpecialOpeningEndDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                    }
                }
                Section("時間") {
                    HStack {
                        Text("開館")
                        Spacer()
                        DatePicker("", selection: timeBinding($draftSpecialOpeningOpenTime, defaultTime: "10:00"), displayedComponents: .hourAndMinute)
                            .labelsHidden()
                    }
                    HStack {
                        Text("閉館")
                        Spacer()
                        DatePicker("", selection: timeBinding($draftSpecialOpeningCloseTime, defaultTime: "17:00"), displayedComponents: .hourAndMinute)
                            .labelsHidden()
                    }
                    HStack {
                        Text("最終入場")
                        Spacer()
                        if draftSpecialOpeningLastEntryTime != nil {
                            HStack(spacing: 8) {
                                DatePicker("", selection: timeBindingOptional($draftSpecialOpeningLastEntryTime, defaultTime: draftSpecialOpeningCloseTime), displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                                Button {
                                    draftSpecialOpeningLastEntryTime = nil
                                } label: {
                                    Image(systemName: "minus.circle")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        } else {
                            HStack(spacing: 6) {
                                Text("未設定")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Button {
                                    draftSpecialOpeningLastEntryTime = draftSpecialOpeningCloseTime
                                } label: {
                                    Image(systemName: "plus.circle")
                                        .foregroundStyle(.blue)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .navigationTitle(editingSpecialOpeningIndex == nil ? "特別開館時間" : "特別開館時間を編集")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        editingSpecialOpeningIndex = nil
                        showSpecialOpeningEditor = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(editingSpecialOpeningIndex == nil ? "追加" : "保存") {
                        onCommit()
                        showSpecialOpeningEditor = false
                    }
                    .disabled(specialOpeningMode == .weekday && draftSpecialOpeningWeekdays.isEmpty)
                }
            }
        }
        .environment(\.locale, Locale(identifier: "ja_JP"))
        .environment(\.calendar, Calendar(identifier: .gregorian))
    }

    private func weekdayShortLabel(_ weekday: Weekday) -> String {
        switch weekday {
        case .monday: return "月"
        case .tuesday: return "火"
        case .wednesday: return "水"
        case .thursday: return "木"
        case .friday: return "金"
        case .saturday: return "土"
        case .sunday: return "日"
        }
    }

    private func timeBindingOptional(_ value: Binding<String?>, defaultTime: String) -> Binding<Date> {
        Binding<Date>(
            get: {
                timeDate(from: value.wrappedValue) ?? timeDate(from: defaultTime) ?? Date()
            },
            set: { newDate in
                value.wrappedValue = timeString(from: newDate)
            }
        )
    }

    private func timeBinding(_ value: Binding<String>, defaultTime: String) -> Binding<Date> {
        Binding<Date>(
            get: {
                timeDate(from: value.wrappedValue) ?? timeDate(from: defaultTime) ?? Date()
            },
            set: { newDate in
                value.wrappedValue = timeString(from: newDate)
            }
        )
    }

    private func timeDate(from text: String?) -> Date? {
        guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter.date(from: text)
    }

    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

private struct AdmissionFeeEditorSheetView: View {
    @Binding var editingAdmissionFeeIndex: Int?
    @Binding var showAdmissionFeeEditor: Bool
    @Binding var draftAdmissionLabel: String
    @Binding var draftAdmissionPriceText: String
    @Binding var draftAdmissionNote: String
    let canSaveAdmissionFee: Bool
    let onCommit: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("区分") {
                    TextField("例: 一般 / 高校生・大学生", text: $draftAdmissionLabel)
                        .textInputAutocapitalization(.never)
                }
                Section("金額") {
                    TextField("例: 1200（空欄可）", text: $draftAdmissionPriceText)
                        .keyboardType(.numberPad)
                }
                Section("メモ") {
                    TextField("任意", text: $draftAdmissionNote)
                }
            }
            .navigationTitle(editingAdmissionFeeIndex == nil ? "入館料を追加" : "入館料を編集")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        editingAdmissionFeeIndex = nil
                        showAdmissionFeeEditor = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(editingAdmissionFeeIndex == nil ? "追加" : "保存") {
                        onCommit()
                        showAdmissionFeeEditor = false
                    }
                    .disabled(!canSaveAdmissionFee)
                }
            }
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
