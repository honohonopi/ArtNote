import SwiftUI
import Observation
import MapKit
import UIKit

/// 登録画面と編集画面で共有する、保存前の展覧会入力状態。
@MainActor
@Observable
final class ExhibitionDraft {
    var title: String
    var venue: String
    var startDate: Date
    var endDate: Date
    var urlString: String
    var catalogTotalCountStr: String
    var addressLine: String
    var hasManuallyEditedDates = false
    var isApplyingAutoDates = false

    var pickedColor: Color?
    var autoColor: UIColor?
    var posterThumbData: Data?

    var tempCoordinate: CLLocationCoordinate2D?
    var previewRegion: MKCoordinateRegion
    var showMapPicker = false

    var scheduleOpenTime: String?
    var scheduleCloseTime: String?
    var scheduleLastEntryTime: String?
    var scheduleClosedWeekdays: [Weekday]
    var scheduleHolidayHandling: HolidayHandling?
    var scheduleClosedDateRules: [DateRule]
    var scheduleOpenDateRules: [DateRule]
    var scheduleSpecialOpenings: [SpecialOpening]

    var editingSpecialOpeningIndex: Int?
    var showSpecialOpeningEditor = false
    var specialOpeningMode: SpecialOpeningInputMode = .date
    var draftSpecialOpeningDate = Date()
    var draftSpecialOpeningStartDate = Date()
    var draftSpecialOpeningEndDate = Calendar.japan.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    var draftSpecialOpeningWeekdays: Set<Weekday> = []
    var draftSpecialOpeningOpenTime = "10:00"
    var draftSpecialOpeningCloseTime = "17:00"
    var draftSpecialOpeningLastEntryTime: String?

    var admissionFees: [AdmissionFeeRule]
    var reservationRequired: Bool?
    var showAdmissionFees = false
    var showAdmissionFeeEditor = false
    var editingAdmissionFeeIndex: Int?
    var draftAdmissionLabel = ""
    var draftAdmissionPriceText = ""
    var draftAdmissionNote = ""
    var draftAdmissionTargets: [UserTicketCategory] = []

    init() {
        title = ""
        venue = ""
        startDate = Date()
        endDate = Calendar.japan.date(byAdding: .day, value: 30, to: Date()) ?? Date()
        urlString = ""
        catalogTotalCountStr = ""
        addressLine = ""
        pickedColor = nil
        autoColor = nil
        posterThumbData = nil
        tempCoordinate = nil
        previewRegion = Self.defaultRegion
        scheduleOpenTime = nil
        scheduleCloseTime = nil
        scheduleLastEntryTime = nil
        scheduleClosedWeekdays = []
        scheduleHolidayHandling = nil
        scheduleClosedDateRules = []
        scheduleOpenDateRules = []
        scheduleSpecialOpenings = []
        admissionFees = []
        reservationRequired = nil
    }

    init(exhibition: Exhibition) {
        title = exhibition.title
        venue = exhibition.venue
        startDate = exhibition.startDate
        endDate = exhibition.endDate
        urlString = exhibition.url?.absoluteString ?? ""
        catalogTotalCountStr = exhibition.catalogTotalCount.map(String.init) ?? ""
        addressLine = exhibition.address ?? ""
        pickedColor = exhibition.uiColor.map(Color.init) ?? .blue
        autoColor = exhibition.uiColor
        posterThumbData = exhibition.posterThumbData
        tempCoordinate = exhibition.coordinate
        previewRegion = exhibition.coordinate.map {
            MKCoordinateRegion(center: $0, span: .init(latitudeDelta: 0.01, longitudeDelta: 0.01))
        } ?? Self.defaultRegion
        scheduleOpenTime = exhibition.scheduleOpenTime
        scheduleCloseTime = exhibition.scheduleCloseTime
        scheduleLastEntryTime = exhibition.scheduleLastEntryTime
        scheduleClosedWeekdays = exhibition.scheduleClosedWeekdays.compactMap { Weekday(rawValue: $0.lowercased()) }
        scheduleHolidayHandling = Self.parseHolidayHandling(exhibition.scheduleHolidayHandling)
        scheduleClosedDateRules = exhibition.scheduleClosedDateRules.compactMap { $0.toDateRule() }
        scheduleOpenDateRules = exhibition.scheduleOpenDateRules.compactMap { $0.toDateRule() }.filter {
            if case .date = $0.rule { return true }
            return false
        }
        scheduleSpecialOpenings = exhibition.scheduleSpecialOpenings.compactMap { $0.toSpecialOpening() }
        admissionFees = exhibition.admissionFeeRules
        reservationRequired = exhibition.reservationRequired
    }

    var hasScheduleInfo: Bool {
        scheduleOpenTime != nil ||
            scheduleCloseTime != nil ||
            scheduleLastEntryTime != nil ||
            !scheduleClosedWeekdays.isEmpty ||
            scheduleHolidayHandling != nil ||
            !scheduleClosedDateRules.isEmpty ||
            !scheduleOpenDateRules.isEmpty ||
            !scheduleSpecialOpenings.isEmpty
    }

    var canSaveAdmissionFee: Bool {
        let label = draftAdmissionLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        let note = draftAdmissionNote.trimmingCharacters(in: .whitespacesAndNewlines)
        let price = draftAdmissionPriceText.trimmingCharacters(in: .whitespacesAndNewlines)
        return !label.isEmpty && (price.isEmpty || Int(price) != nil) && (!price.isEmpty || !note.isEmpty)
    }

    func prepareMapPicker() {
        showMapPicker = true
    }

    func applyMapSelection(coordinate: CLLocationCoordinate2D, address: String?) {
        tempCoordinate = coordinate
        previewRegion = MKCoordinateRegion(
            center: coordinate,
            span: .init(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        if let address, !address.isEmpty {
            addressLine = address
        }
    }

    func beginAddingSpecialOpening() {
        editingSpecialOpeningIndex = nil
        prepareSpecialOpeningEditor()
        showSpecialOpeningEditor = true
    }

    func beginEditingSpecialOpening(at index: Int) {
        guard scheduleSpecialOpenings.indices.contains(index) else { return }
        editingSpecialOpeningIndex = index
        prepareSpecialOpeningEditor(for: scheduleSpecialOpenings[index])
        showSpecialOpeningEditor = true
    }

    func prepareSpecialOpeningEditor(for opening: SpecialOpening? = nil) {
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
            draftSpecialOpeningEndDate = Calendar.japan.date(byAdding: .day, value: 1, to: Date()) ?? Date()
            draftSpecialOpeningWeekdays = []
            draftSpecialOpeningOpenTime = scheduleOpenTime ?? "10:00"
            draftSpecialOpeningCloseTime = scheduleCloseTime ?? "17:00"
            draftSpecialOpeningLastEntryTime = scheduleLastEntryTime
        }
    }

    func commitDraftSpecialOpening() {
        let items = buildDraftSpecialOpenings()
        if let index = editingSpecialOpeningIndex {
            scheduleSpecialOpenings.remove(at: index)
            scheduleSpecialOpenings.insert(contentsOf: items, at: index)
            editingSpecialOpeningIndex = nil
        } else {
            scheduleSpecialOpenings.append(contentsOf: items)
        }
    }

    func toggleDraftWeekday(_ weekday: Weekday) {
        if draftSpecialOpeningWeekdays.contains(weekday) {
            draftSpecialOpeningWeekdays.remove(weekday)
        } else {
            draftSpecialOpeningWeekdays.insert(weekday)
        }
    }

    func beginAddingAdmissionFee() {
        editingAdmissionFeeIndex = nil
        prepareAdmissionFeeEditor()
        showAdmissionFeeEditor = true
    }

    func beginEditingAdmissionFee(at index: Int) {
        guard admissionFees.indices.contains(index) else { return }
        editingAdmissionFeeIndex = index
        prepareAdmissionFeeEditor(for: admissionFees[index])
        showAdmissionFeeEditor = true
    }

    func prepareAdmissionFeeEditor(for fee: AdmissionFeeRule? = nil) {
        draftAdmissionLabel = fee?.rawLabel ?? ""
        draftAdmissionPriceText = fee?.priceYen.map(String.init) ?? ""
        draftAdmissionNote = fee?.note ?? ""
        draftAdmissionTargets = fee?.targets ?? []
    }

    func commitAdmissionFee() {
        let label = draftAdmissionLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        let note = draftAdmissionNote.trimmingCharacters(in: .whitespacesAndNewlines)
        let priceText = draftAdmissionPriceText.trimmingCharacters(in: .whitespacesAndNewlines)
        var fee = AdmissionFeeRule(
            rawLabel: label,
            priceYen: priceText.isEmpty ? nil : Int(priceText),
            note: note.isEmpty ? nil : note,
            targets: draftAdmissionTargets
        )
        if let index = editingAdmissionFeeIndex {
            fee.id = admissionFees[index].id
            admissionFees[index] = fee
            editingAdmissionFeeIndex = nil
        } else {
            admissionFees.append(fee)
        }
    }

    func reservationStatusText(_ value: Bool?) -> String {
        switch value {
        case .some(true): return "事前予約制"
        case .some(false): return "予約不要"
        case .none: return "記載なし"
        }
    }

    func admissionPriceText(_ fee: AdmissionFeeRule) -> String? {
        if fee.isFreeLike { return "無料" }
        return fee.priceYen.map { "\($0)円" }
    }

    func applyPosterAppearance(from image: UIImage) {
        if let thumbnail = ImageThumbService.makeThumbnail(image) {
            posterThumbData = thumbnail
        }
        if let color = DominantColorService.dominantColor(from: image) {
            pickedColor = Color(color)
            autoColor = color
        }
    }

    func removePoster() {
        posterThumbData = nil
    }

    func autoResolveAddress(from venue: String) async {
        let query = venue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty,
              addressLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let result = try? await VenueGeocodingService.geocodeWithAddress(query)
        else { return }
        if let address = result.address, !address.isEmpty {
            addressLine = address
        }
        if tempCoordinate == nil {
            applyMapSelection(coordinate: result.coordinate, address: nil)
        }
    }

    func triggerGeocoding() {
        Task {
            let query = venue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !query.isEmpty, let coordinate = try? await VenueGeocodingService.geocode(query) else { return }
            applyMapSelection(coordinate: coordinate, address: nil)
        }
    }

    func makeExhibition() -> Exhibition {
        let exhibition = Exhibition(
            title: title,
            venue: venue,
            address: addressLine.trimmingCharacters(in: .whitespacesAndNewlines),
            startDate: startDate,
            endDate: max(startDate, endDate),
            url: urlString.normalizedWebURL(),
            catalogTotalCount: Int(catalogTotalCountStr.trimmingCharacters(in: .whitespacesAndNewlines))
        )
        apply(to: exhibition)
        return exhibition
    }

    func apply(to exhibition: Exhibition) {
        exhibition.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        exhibition.venue = venue.trimmingCharacters(in: .whitespacesAndNewlines)
        exhibition.address = addressLine.trimmingCharacters(in: .whitespacesAndNewlines)
        exhibition.startDate = startDate
        exhibition.endDate = max(startDate, endDate)
        exhibition.url = urlString.normalizedWebURL()
        exhibition.catalogTotalCount = Int(catalogTotalCountStr.trimmingCharacters(in: .whitespacesAndNewlines))
        exhibition.scheduleOpenTime = scheduleOpenTime
        exhibition.scheduleCloseTime = scheduleCloseTime
        exhibition.scheduleLastEntryTime = scheduleLastEntryTime
        exhibition.scheduleClosedWeekdays = scheduleClosedWeekdays.map(\.rawValue)
        exhibition.scheduleHolidayHandling = scheduleHolidayHandling.map(Self.holidayHandlingRawValue)
        exhibition.scheduleClosedDateRules = scheduleClosedDateRules.map { $0.toRecord() }
        exhibition.scheduleOpenDateRules = scheduleOpenDateRules.map { $0.toRecord() }
        exhibition.scheduleSpecialOpenings = scheduleSpecialOpenings.map { $0.toRecord() }
        exhibition.admissionFeeRules = admissionFees
        exhibition.reservationRequired = reservationRequired
        exhibition.posterThumbData = posterThumbData
        if let coordinate = tempCoordinate { exhibition.setCoordinate(coordinate) }
        if let color = pickedColor.map(UIColor.init) ?? autoColor { exhibition.setColor(color) }
    }

    private func buildDraftSpecialOpenings() -> [SpecialOpening] {
        let make: (SpecialOpening.Rule) -> SpecialOpening = {
            SpecialOpening(
                rule: $0,
                openTime: self.draftSpecialOpeningOpenTime,
                closeTime: self.draftSpecialOpeningCloseTime,
                lastEntryTime: self.draftSpecialOpeningLastEntryTime,
                note: nil
            )
        }
        switch specialOpeningMode {
        case .date:
            return [make(.date(draftSpecialOpeningDate))]
        case .weekday:
            return draftSpecialOpeningWeekdays
                .sorted { $0.calendarValue < $1.calendarValue }
                .map { make(.weekday($0)) }
        case .range:
            return [make(.range(
                start: min(draftSpecialOpeningStartDate, draftSpecialOpeningEndDate),
                end: max(draftSpecialOpeningStartDate, draftSpecialOpeningEndDate)
            ))]
        }
    }

    private static var defaultRegion: MKCoordinateRegion {
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671),
            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        )
    }

    private static func parseHolidayHandling(_ value: String?) -> HolidayHandling? {
        switch value?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() {
        case "NONE": return HolidayHandling.none
        case "OPEN_ON_HOLIDAY": return .openOnHoliday
        case "OPEN_ON_HOLIDAY_CLOSE_NEXT_WEEKDAY": return .openOnHolidayCloseNextWeekday
        default: return nil
        }
    }

    private static func holidayHandlingRawValue(_ value: HolidayHandling) -> String {
        switch value {
        case .none: return "NONE"
        case .openOnHoliday: return "OPEN_ON_HOLIDAY"
        case .openOnHolidayCloseNextWeekday: return "OPEN_ON_HOLIDAY_CLOSE_NEXT_WEEKDAY"
        }
    }
}
