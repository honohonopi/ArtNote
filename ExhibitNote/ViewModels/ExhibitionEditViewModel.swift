//
//  ExhibitionEditViewModel.swift
//  ExhibitNote
//
//  Created by Honoka Nishiyama on 2026/01/06.
//

import SwiftUI
import Observation
import MapKit
import PhotosUI
import SwiftData
import UIKit

@MainActor
@Observable
final class ExhibitionEditViewModel {
    private let exhibition: Exhibition

    var title: String
    var venue: String
    var startDate: Date
    var endDate: Date
    var isApplyingAutoDates = false
    var hasManuallyEditedDates = false
    var urlString: String
    var catalogTotalCountStr: String
    var addressLine: String

    var pickedColor: Color?
    var autoColor: UIColor?
    var posterThumbData: Data?
    var localPreviewImage: UIImage?

    var showCamera = false
    var showLibrary = false
    var selectedPhotoItem: PhotosPickerItem?

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

    var editingSpecialOpeningIndex: Int? = nil
    var showSpecialOpeningEditor = false
    var specialOpeningMode: SpecialOpeningInputMode = .date
    var draftSpecialOpeningDate = Date()
    var draftSpecialOpeningStartDate = Date()
    var draftSpecialOpeningEndDate = Calendar.japan.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    var draftSpecialOpeningWeekdays: Set<Weekday> = []
    var draftSpecialOpeningOpenTime = "10:00"
    var draftSpecialOpeningCloseTime = "17:00"
    var draftSpecialOpeningLastEntryTime: String? = nil

    var admissionFees: [AdmissionFeeRule]
    var reservationRequired: Bool?
    var showAdmissionFees = false
    var showAdmissionFeeEditor = false
    var editingAdmissionFeeIndex: Int? = nil
    var draftAdmissionLabel: String = ""
    var draftAdmissionPriceText: String = ""
    var draftAdmissionNote: String = ""
    var draftAdmissionTargets: [UserTicketCategory] = []

    init(exhibition: Exhibition) {
        self.exhibition = exhibition
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

    func save(in context: ModelContext) async throws {
        try await ExhibitionPersistenceService(context: context).update(exhibition) {
            applyChanges(to: exhibition)
        }
    }

    func prepareMapPicker() {
        showMapPicker = true
    }

    func applyMapSelection(coordinate: CLLocationCoordinate2D, address: String?) {
        tempCoordinate = coordinate
        previewRegion.center = coordinate
        previewRegion.span = .init(latitudeDelta: 0.01, longitudeDelta: 0.01)
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

    func removePoster() {
        posterThumbData = nil
        localPreviewImage = nil
    }

    func reservationStatusText(_ value: Bool?) -> String {
        switch value {
        case .some(true):
            return "事前予約制"
        case .some(false):
            return "予約不要"
        case .none:
            return "記載なし"
        }
    }

    func admissionPriceText(_ fee: AdmissionFeeRule) -> String? {
        if fee.isFreeLike { return "無料" }
        if let price = fee.priceYen { return "\(price)円" }
        return nil
    }

    private func applyChanges(to exhibition: Exhibition) {
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

    func handleSelectedPhotoItem(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        defer { selectedPhotoItem = nil }
        guard let image = await item.loadUIImage() else { return }
        handlePickedImage(image)
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
        case "NONE": return HolidayHandling.none
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
