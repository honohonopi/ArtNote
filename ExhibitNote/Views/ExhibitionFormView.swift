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

    @State private var scheduleOpenTime: String? = nil
    @State private var scheduleCloseTime: String? = nil
    @State private var scheduleLastEntryTime: String? = nil
    @State private var scheduleClosedWeekdays: [Weekday] = []
    @State private var scheduleHolidayHandling: HolidayHandling? = nil
    @State private var scheduleClosedDateRules: [DateRule] = []
    @State private var scheduleOpenDateRules: [DateRule] = []
    @State private var scheduleSpecialOpenings: [SpecialOpening] = []
    @State private var editingSpecialOpeningIndex: Int? = nil
    @State private var showSpecialOpeningEditor = false
    @State private var specialOpeningMode: SpecialOpeningInputMode = .date
    @State private var draftSpecialOpeningDate = Date()
    @State private var draftSpecialOpeningStartDate = Date()
    @State private var draftSpecialOpeningEndDate = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    @State private var draftSpecialOpeningWeekdays: Set<Weekday> = []
    @State private var draftSpecialOpeningOpenTime = "10:00"
    @State private var draftSpecialOpeningCloseTime = "17:00"
    @State private var draftSpecialOpeningLastEntryTime: String? = nil

    @State private var admissionFees: [AdmissionFeeRule] = []
    @State private var reservationRequired: Bool? = nil
    @State private var showAdmissionFees = false
    
    struct MapPickerPayload: Identifiable {
        let id = UUID()
        let query: String
    }

    private enum SpecialOpeningInputMode: String, CaseIterable, Identifiable {
        case date
        case weekday
        case range

        var id: String { rawValue }

        var label: String {
            switch self {
            case .date: return "単日"
            case .weekday: return "曜日"
            case .range: return "期間"
            }
        }
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
                let result: FlyerExtractionResult
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
                await MainActor.run {
                    if let schedule = result.schedule {
                        scheduleOpenTime = schedule.openTime
                        scheduleCloseTime = schedule.closeTime
                        scheduleLastEntryTime = schedule.lastEntryTime
                        scheduleClosedWeekdays = schedule.closedWeekdays
                        scheduleHolidayHandling = schedule.holidayHandling
                        scheduleClosedDateRules = schedule.closedDateRules
                        scheduleOpenDateRules = schedule.openDateRules.filter { rule in
                            if case .date = rule.rule { return true }
                            return false
                        }
                        scheduleSpecialOpenings = schedule.specialOpenings
                    } else {
                        scheduleOpenTime = nil
                        scheduleCloseTime = nil
                        scheduleLastEntryTime = nil
                        scheduleClosedWeekdays = []
                        scheduleHolidayHandling = nil
                        scheduleClosedDateRules = []
                        scheduleOpenDateRules = []
                        scheduleSpecialOpenings = []
                    }
                    if let fees = result.admissionFees, !fees.isEmpty {
                        admissionFees = fees
                    }
                    if let reservation = result.reservationRequired {
                        reservationRequired = reservation
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
        ex.scheduleOpenTime = scheduleOpenTime
        ex.scheduleCloseTime = scheduleCloseTime
        ex.scheduleLastEntryTime = scheduleLastEntryTime
        ex.scheduleClosedWeekdays = scheduleClosedWeekdays.map { $0.rawValue }
        ex.scheduleHolidayHandling = scheduleHolidayHandling.map { holidayHandlingRaw($0) }
        ex.scheduleClosedDateRules = scheduleClosedDateRules.map { $0.toRecord() }
        ex.scheduleOpenDateRules = scheduleOpenDateRules.map { $0.toRecord() }
        ex.scheduleSpecialOpenings = scheduleSpecialOpenings.map { $0.toRecord() }
        ex.admissionFeeRules = admissionFees
        ex.reservationRequired = reservationRequired
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
    
    private var hasScheduleInfo: Bool {
        scheduleOpenTime != nil ||
        scheduleCloseTime != nil ||
        scheduleLastEntryTime != nil ||
        !scheduleClosedWeekdays.isEmpty ||
        scheduleHolidayHandling != nil ||
        !scheduleClosedDateRules.isEmpty ||
        !scheduleOpenDateRules.isEmpty ||
        !scheduleSpecialOpenings.isEmpty
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
        let labels = scheduleClosedWeekdays.compactMap { map[$0] }
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

    private var displayAdmissionFees: [AdmissionFeeRule] {
        admissionFees.filter { fee in
            fee.priceYen != nil ||
            (fee.note?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
        }
    }

    private var scheduleList: some View {
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
                Button {
                    editingSpecialOpeningIndex = nil
                    prepareSpecialOpeningEditor()
                    showSpecialOpeningEditor = true
                } label: {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }
            ForEach(scheduleSpecialOpenings.indices, id: \.self) { idx in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(specialOpeningLabel(scheduleSpecialOpenings[idx]))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(scheduleSpecialOpenings[idx].openTime)〜\(scheduleSpecialOpenings[idx].closeTime)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Menu {
                            Button("編集") {
                                editingSpecialOpeningIndex = idx
                                prepareSpecialOpeningEditor(for: scheduleSpecialOpenings[idx])
                                showSpecialOpeningEditor = true
                            }
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

    private func prepareSpecialOpeningEditor(for opening: SpecialOpening? = nil) {
        if let opening {
            switch opening.rule {
            case .date(let date):
                specialOpeningMode = .date
                draftSpecialOpeningDate = date
                draftSpecialOpeningWeekdays = []
            case .weekday(let weekday):
                specialOpeningMode = .weekday
                draftSpecialOpeningDate = Date()
                draftSpecialOpeningWeekdays = [weekday]
            case .range(let start, let end):
                specialOpeningMode = .range
                draftSpecialOpeningStartDate = start
                draftSpecialOpeningEndDate = end
                draftSpecialOpeningWeekdays = []
            }
            draftSpecialOpeningOpenTime = opening.openTime
            draftSpecialOpeningCloseTime = opening.closeTime
            draftSpecialOpeningLastEntryTime = opening.lastEntryTime
        } else {
            specialOpeningMode = .date
            draftSpecialOpeningDate = Date()
            draftSpecialOpeningStartDate = Date()
            draftSpecialOpeningEndDate = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
            draftSpecialOpeningWeekdays = []
            draftSpecialOpeningOpenTime = scheduleOpenTime ?? "10:00"
            draftSpecialOpeningCloseTime = scheduleCloseTime ?? "17:00"
            draftSpecialOpeningLastEntryTime = scheduleLastEntryTime
        }
    }

    private func buildDraftSpecialOpenings() -> [SpecialOpening] {
        let open = draftSpecialOpeningOpenTime
        let close = draftSpecialOpeningCloseTime
        let last = draftSpecialOpeningLastEntryTime
        switch specialOpeningMode {
        case .date:
            return [
                SpecialOpening(rule: .date(draftSpecialOpeningDate),
                               openTime: open,
                               closeTime: close,
                               lastEntryTime: last,
                               note: nil)
            ]
        case .weekday:
            let weekdays = draftSpecialOpeningWeekdays.sorted { $0.calendarValue < $1.calendarValue }
            return weekdays.map { weekday in
                SpecialOpening(rule: .weekday(weekday),
                               openTime: open,
                               closeTime: close,
                               lastEntryTime: last,
                               note: nil)
            }
        case .range:
            let start = min(draftSpecialOpeningStartDate, draftSpecialOpeningEndDate)
            let end = max(draftSpecialOpeningStartDate, draftSpecialOpeningEndDate)
            return [
                SpecialOpening(rule: .range(start: start, end: end),
                               openTime: open,
                               closeTime: close,
                               lastEntryTime: last,
                               note: nil)
            ]
        }
    }

    private func commitDraftSpecialOpening() {
        let items = buildDraftSpecialOpenings()
        if let index = editingSpecialOpeningIndex {
            scheduleSpecialOpenings.remove(at: index)
            if !items.isEmpty {
                scheduleSpecialOpenings.insert(contentsOf: items, at: index)
            }
            editingSpecialOpeningIndex = nil
        } else {
            scheduleSpecialOpenings.append(contentsOf: items)
        }
    }

    private func toggleDraftWeekday(_ weekday: Weekday) {
        if draftSpecialOpeningWeekdays.contains(weekday) {
            draftSpecialOpeningWeekdays.remove(weekday)
        } else {
            draftSpecialOpeningWeekdays.insert(weekday)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
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
                            .onSubmit {
                                triggerGeocoding()
                            }
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
                        Button {
                            // 住所があれば住所、なければ会場名。空なら何もしない
                            let q = addressLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? venue.trimmingCharacters(in: .whitespacesAndNewlines)
                            : addressLine.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !q.isEmpty else { return }
                            mapPickerPayload = MapPickerPayload(query: q)   // ← これでシートを開く
                        } label: {
                            Image(systemName: "map")
                                .imageScale(.large)
                                .foregroundStyle(.blue)   // ← 青に
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
                Section("チケット情報") {
                    DisclosureGroup(isExpanded: $showAdmissionFees) {
                        if displayAdmissionFees.isEmpty {
                            Text("未取得")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(displayAdmissionFees) { fee in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(fee.rawLabel)
                                        Spacer()
                                        if let priceText = admissionPriceText(fee) {
                                            Text(priceText)
                                                .foregroundStyle(.secondary)
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
                Section {
                    DisclosureGroup {
                        scheduleList
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
                    .background(Color.blue.opacity(0.2), in: Capsule())
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
            .sheet(isPresented: $showSpecialOpeningEditor) {
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
                                            toggleDraftWeekday(day)
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
                                commitDraftSpecialOpening()
                                showSpecialOpeningEditor = false
                            }
                            .disabled(specialOpeningMode == .weekday && draftSpecialOpeningWeekdays.isEmpty)
                        }
                    }
                }
                .environment(\.locale, Locale(identifier: "ja_JP"))
                .environment(\.calendar, Calendar(identifier: .gregorian))
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
