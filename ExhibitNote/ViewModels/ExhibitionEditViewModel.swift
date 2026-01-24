//
//  ExhibitionEditViewModel.swift
//  ExhibitNote
//
//  Created by Honoka Nishiyama on 2026/01/06.
//

import SwiftUI
import MapKit
import UIKit

@MainActor
final class ExhibitionEditViewModel: ObservableObject {
    @Published var title: String
    @Published var venue: String
    @Published var startDate: Date
    @Published var endDate: Date
    @Published var isApplyingAutoDates = false
    @Published var hasManuallyEditedDates = false
    @Published var urlString: String
    @Published var catalogTotalCountStr: String
    @Published var addressLine: String

    @Published var pickedColor: Color?
    @Published var autoColor: UIColor?
    @Published var posterThumbData: Data?
    @Published var localPreviewImage: UIImage?

    @Published var showCamera = false
    @Published var showLibrary = false

    @Published var tempCoordinate: CLLocationCoordinate2D?
    @Published var previewRegion: MKCoordinateRegion
    @Published var mapPickerPayload: MapPickerPayload?

    @Published var scheduleOpenTime: String?
    @Published var scheduleCloseTime: String?
    @Published var scheduleLastEntryTime: String?
    @Published var scheduleClosedWeekdays: [Weekday]
    @Published var scheduleHolidayHandling: HolidayHandling?
    @Published var scheduleClosedDateRules: [DateRule]
    @Published var scheduleOpenDateRules: [DateRule]
    @Published var scheduleSpecialOpenings: [SpecialOpening]

    @Published var editingSpecialOpeningIndex: Int? = nil
    @Published var showSpecialOpeningEditor = false
    @Published var specialOpeningMode: SpecialOpeningInputMode = .date
    @Published var draftSpecialOpeningDate = Date()
    @Published var draftSpecialOpeningStartDate = Date()
    @Published var draftSpecialOpeningEndDate = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    @Published var draftSpecialOpeningWeekdays: Set<Weekday> = []
    @Published var draftSpecialOpeningOpenTime = "10:00"
    @Published var draftSpecialOpeningCloseTime = "17:00"
    @Published var draftSpecialOpeningLastEntryTime: String? = nil

    @Published var admissionFees: [AdmissionFeeRule]
    @Published var reservationRequired: Bool?
    @Published var showAdmissionFees = false
    @Published var showAdmissionFeeEditor = false
    @Published var editingAdmissionFeeIndex: Int? = nil
    @Published var draftAdmissionLabel: String = ""
    @Published var draftAdmissionPriceText: String = ""
    @Published var draftAdmissionNote: String = ""
    @Published var draftAdmissionTargets: [UserTicketCategory] = []

    struct MapPickerPayload: Identifiable {
        let id = UUID()
        let query: String
    }

    init(exhibition: Exhibition) {
        title = exhibition.title
        venue = exhibition.venue
        addressLine = exhibition.address ?? ""
        startDate = exhibition.startDate
        endDate = exhibition.endDate
        urlString = exhibition.url?.absoluteString ?? ""
        catalogTotalCountStr = exhibition.catalogTotalCount.map(String.init) ?? ""

        if let ui = exhibition.uiColor {
            pickedColor = Color(ui)
            autoColor = ui
        } else {
            pickedColor = .blue
            autoColor = nil
        }
        posterThumbData = exhibition.posterThumbData
        localPreviewImage = nil

        if let c = exhibition.coordinate {
            tempCoordinate = c
            previewRegion = MKCoordinateRegion(center: c, span: .init(latitudeDelta: 0.01, longitudeDelta: 0.01))
        } else {
            previewRegion = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671),
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            )
        }
        mapPickerPayload = nil

        scheduleOpenTime = exhibition.scheduleOpenTime
        scheduleCloseTime = exhibition.scheduleCloseTime
        scheduleLastEntryTime = exhibition.scheduleLastEntryTime
        scheduleClosedWeekdays = exhibition.scheduleClosedWeekdays.compactMap { Weekday(rawValue: $0.lowercased()) }
        scheduleHolidayHandling = Self.parseHolidayHandling(exhibition.scheduleHolidayHandling)
        scheduleClosedDateRules = exhibition.scheduleClosedDateRules.compactMap { $0.toDateRule() }
        scheduleOpenDateRules = exhibition.scheduleOpenDateRules.compactMap { $0.toDateRule() }.filter { rule in
            if case .date = rule.rule { return true }
            return false
        }
        scheduleSpecialOpenings = exhibition.scheduleSpecialOpenings.compactMap { $0.toSpecialOpening() }

        admissionFees = exhibition.admissionFeeRules
        reservationRequired = exhibition.reservationRequired
    }

    func applyChanges(to exhibition: Exhibition) {
        if endDate < startDate { endDate = startDate }
        exhibition.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        exhibition.venue = venue.trimmingCharacters(in: .whitespacesAndNewlines)
        exhibition.address = addressLine.trimmingCharacters(in: .whitespacesAndNewlines)
        exhibition.startDate = startDate
        exhibition.endDate = endDate
        if let color = pickedColor {
            exhibition.setColor(UIColor(color))
        }
        exhibition.url = urlString.normalizedWebURL()
        exhibition.catalogTotalCount = Int(catalogTotalCountStr.trimmingCharacters(in: .whitespacesAndNewlines))
        exhibition.scheduleOpenTime = scheduleOpenTime
        exhibition.scheduleCloseTime = scheduleCloseTime
        exhibition.scheduleLastEntryTime = scheduleLastEntryTime
        exhibition.scheduleClosedWeekdays = scheduleClosedWeekdays.map { $0.rawValue }
        exhibition.scheduleHolidayHandling = scheduleHolidayHandling.map { Self.holidayHandlingRaw($0) }
        exhibition.scheduleClosedDateRules = scheduleClosedDateRules.map { $0.toRecord() }
        exhibition.scheduleOpenDateRules = scheduleOpenDateRules.map { $0.toRecord() }
        exhibition.scheduleSpecialOpenings = scheduleSpecialOpenings.map { $0.toRecord() }
        exhibition.admissionFeeRules = admissionFees
        exhibition.reservationRequired = reservationRequired
        exhibition.posterThumbData = posterThumbData
        if let c = tempCoordinate {
            exhibition.setCoordinate(c)
        }
    }

    func handlePickedImage(_ image: UIImage) {
        if let thumb = ImageThumbService.makeThumbnail(image) {
            posterThumbData = thumb
        }
        localPreviewImage = image
        if let ui = DominantColorService.dominantColor(from: image) {
            pickedColor = Color(ui)
            autoColor = ui
        }
    }

    func triggerGeocoding() {
        Task {
            let v = venue.trimmingCharacters(in: .whitespaces)
            guard !v.isEmpty else { return }
            if let c = try? await VenueGeocodingService.geocode(v) {
                tempCoordinate = c
                previewRegion.center = c
                previewRegion.span = .init(latitudeDelta: 0.01, longitudeDelta: 0.01)
            }
        }
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
            draftSpecialOpeningEndDate = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
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
            if !items.isEmpty {
                scheduleSpecialOpenings.insert(contentsOf: items, at: index)
            }
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

    func prepareAdmissionFeeEditor(for fee: AdmissionFeeRule? = nil) {
        if let fee {
            draftAdmissionLabel = fee.rawLabel
            if let price = fee.priceYen {
                draftAdmissionPriceText = "\(price)"
            } else {
                draftAdmissionPriceText = ""
            }
            draftAdmissionNote = fee.note ?? ""
            draftAdmissionTargets = fee.targets
        } else {
            draftAdmissionLabel = ""
            draftAdmissionPriceText = ""
            draftAdmissionNote = ""
            draftAdmissionTargets = []
        }
    }

    func commitAdmissionFee() {
        let label = draftAdmissionLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        let noteText = draftAdmissionNote.trimmingCharacters(in: .whitespacesAndNewlines)
        let priceText = draftAdmissionPriceText.trimmingCharacters(in: .whitespacesAndNewlines)
        let price = priceText.isEmpty ? nil : Int(priceText)
        var newFee = AdmissionFeeRule(
            rawLabel: label,
            priceYen: price,
            note: noteText.isEmpty ? nil : noteText,
            targets: draftAdmissionTargets
        )
        if let index = editingAdmissionFeeIndex {
            newFee.id = admissionFees[index].id
            admissionFees[index] = newFee
            editingAdmissionFeeIndex = nil
        } else {
            admissionFees.append(newFee)
        }
    }

    var canSaveAdmissionFee: Bool {
        let label = draftAdmissionLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        let noteText = draftAdmissionNote.trimmingCharacters(in: .whitespacesAndNewlines)
        let priceText = draftAdmissionPriceText.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasPrice = !priceText.isEmpty
        let priceIsValid = priceText.isEmpty || Int(priceText) != nil
        return !label.isEmpty && priceIsValid && (hasPrice || !noteText.isEmpty)
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

    private static func parseHolidayHandling(_ value: String?) -> HolidayHandling? {
        guard let raw = value?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
              !raw.isEmpty
        else { return nil }
        switch raw {
        case "NONE": return .none
        case "OPEN_ON_HOLIDAY": return .openOnHoliday
        case "OPEN_ON_HOLIDAY_CLOSE_NEXT_WEEKDAY": return .openOnHolidayCloseNextWeekday
        default: return nil
        }
    }

    private static func holidayHandlingRaw(_ value: HolidayHandling) -> String {
        switch value {
        case .none:
            return "NONE"
        case .openOnHoliday:
            return "OPEN_ON_HOLIDAY"
        case .openOnHolidayCloseNextWeekday:
            return "OPEN_ON_HOLIDAY_CLOSE_NEXT_WEEKDAY"
        }
    }
}
