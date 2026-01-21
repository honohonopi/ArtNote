//
//  ExhibitionFormSharedViews.swift
//  ExhibitNote
//
//  Created by Honoka Nishiyama on 2026/01/06.
//

import SwiftUI
import UIKit

struct BasicInfoSectionView: View {
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

struct AdmissionInfoSectionView: View {
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
                    Image(systemName: "chineseyuanrenminbisign")
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
                Image(systemName: "info")
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

struct ScheduleSectionView<Content: View>: View {
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

struct ScheduleEditorListView: View {
    @Binding var scheduleOpenTime: String?
    @Binding var scheduleCloseTime: String?
    @Binding var scheduleLastEntryTime: String?
    @Binding var scheduleClosedWeekdays: [Weekday]
    @Binding var scheduleHolidayHandling: HolidayHandling?
    @Binding var scheduleClosedDateRules: [DateRule]
    @Binding var scheduleOpenDateRules: [DateRule]
    @Binding var scheduleSpecialOpenings: [SpecialOpening]
    let onAddSpecialOpening: () -> Void
    let onEditSpecialOpening: (Int) -> Void

    var body: some View {
        Group {
            HStack {
                Text("開館時間")
                Spacer()
                HStack(spacing: 4) {
                    DatePicker("", selection: timeBindingOptional($scheduleOpenTime, defaultTime: "10:00"), displayedComponents: .hourAndMinute)
                        .labelsHidden()
                    Text("〜")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 16)
                    DatePicker("", selection: timeBindingOptional($scheduleCloseTime, defaultTime: "17:00"), displayedComponents: .hourAndMinute)
                        .labelsHidden()
                }
            }
            HStack {
                Text("最終入場")
                Spacer()
                if scheduleLastEntryTime != nil {
                    HStack(spacing: 8) {
                        DatePicker("", selection: timeBindingOptional($scheduleLastEntryTime, defaultTime: scheduleCloseTime ?? "17:00"), displayedComponents: .hourAndMinute)
                            .labelsHidden()
                        Button {
                            scheduleLastEntryTime = nil
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
                            scheduleLastEntryTime = scheduleCloseTime ?? "17:00"
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
                        let selected = scheduleClosedWeekdays.contains(day)
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
                    Button("記載なし") { scheduleHolidayHandling = nil }
                    Button("祝日対応なし") { scheduleHolidayHandling = .none }
                    Button("祝日は開館") { scheduleHolidayHandling = .openOnHoliday }
                    Button("祝日開館、翌平日休館") { scheduleHolidayHandling = .openOnHolidayCloseNextWeekday }
                } label: {
                    HStack(spacing: 6) {
                        Text(holidayHandlingText(scheduleHolidayHandling))
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
                        scheduleClosedDateRules.append(DateRule(rule: .date(Date()), note: nil))
                    }
                    Button("期間") {
                        let start = Date()
                        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
                        scheduleClosedDateRules.append(DateRule(rule: .range(start: start, end: end), note: nil))
                    }
                } label: {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(.blue)
                }
            }
            ForEach(scheduleClosedDateRules.indices, id: \.self) { idx in
                HStack {
                    Spacer()
                    switch scheduleClosedDateRules[idx].rule {
                    case .date(let date):
                        DatePicker("", selection: Binding(
                            get: { date },
                            set: { newDate in
                                scheduleClosedDateRules[idx].rule = .date(newDate)
                            }
                        ), displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                    case .range(let start, let end):
                        DatePicker("", selection: Binding(
                            get: { start },
                            set: { newStart in
                                scheduleClosedDateRules[idx].rule = .range(start: newStart, end: end)
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
                                scheduleClosedDateRules[idx].rule = .range(start: start, end: newEnd)
                            }
                        ), displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                    }
                    Button {
                        scheduleClosedDateRules.remove(at: idx)
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
                    scheduleOpenDateRules.append(DateRule(rule: .date(Date()), note: nil))
                } label: {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(.blue)
                }
            }
            ForEach(scheduleOpenDateRules.indices, id: \.self) { idx in
                HStack {
                    Spacer()
                    DatePicker("", selection: Binding(
                        get: {
                            if case .date(let date) = scheduleOpenDateRules[idx].rule {
                                return date
                            }
                            return Date()
                        },
                        set: { newDate in
                            scheduleOpenDateRules[idx].rule = .date(newDate)
                        }
                    ), displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    Button {
                        scheduleOpenDateRules.remove(at: idx)
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
                Button(action: onAddSpecialOpening) {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }
            ForEach(scheduleSpecialOpenings.indices, id: \.self) { idx in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(specialOpeningLabel(scheduleSpecialOpenings[idx]))
                            .foregroundStyle(.primary)
                        Spacer()
                        Text("\(scheduleSpecialOpenings[idx].openTime)〜\(scheduleSpecialOpenings[idx].closeTime)")
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                        Menu {
                            Button("編集") { onEditSpecialOpening(idx) }
                            Button("削除", role: .destructive) {
                                scheduleSpecialOpenings.remove(at: idx)
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .foregroundStyle(.blue)
                        }
                    }
                    if let last = scheduleSpecialOpenings[idx].lastEntryTime, !last.isEmpty {
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
        if let idx = scheduleClosedWeekdays.firstIndex(of: weekday) {
            scheduleClosedWeekdays.remove(at: idx)
        } else {
            scheduleClosedWeekdays.append(weekday)
            scheduleClosedWeekdays.sort { $0.calendarValue < $1.calendarValue }
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
}

struct ColorSelectionSectionView: View {
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

struct SpecialOpeningEditorSheetView: View {
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

struct AdmissionFeeEditorSheetView: View {
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
