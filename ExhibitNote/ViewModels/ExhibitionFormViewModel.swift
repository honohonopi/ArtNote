//
//  ExhibitionFormViewModel.swift
//  ExhibitNote
//
//  Created by Honoka Nishiyama on 2026/01/06.
//

import SwiftUI
import MapKit
import PhotosUI
import UIKit

@MainActor
final class ExhibitionFormViewModel: ObservableObject {
    @Published var title = ""
    @Published var venue = ""
    @Published var startDate = Date()
    @Published var endDate = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
    @Published var urlString: String = ""
    @Published var catalogTotalCountStr: String = ""

    @Published var showPhotoPicker = false
    @Published var selectedItem: PhotosPickerItem? = nil
    @Published var ocrAlertMessage: String? = nil
    @Published var showOcrAlert = false

    @Published var titleOptions: [String] = []
    @Published var venueOptions: [String] = []
    @Published var dateOptions: [(Date, Date)] = []

    @Published var selectedTitle: String?
    @Published var selectedVenue: String?
    @Published var selectedDateIndex: Int = 0
    @Published var hasManuallyEditedDates = false
    @Published var isApplyingAutoDates = false
    @Published var isAIAnalyzing = false

    @Published var showReviewSheet = false
    @Published var showMissingAlert = false
    @Published var missingAlertMessage: String = ""
    @Published var pendingAlertMessage: String? = nil

    @Published var pickedColor: Color? = nil
    @Published var autoColor: UIColor? = nil
    @Published var posterThumbData: Data? = nil

    @Published var mapPickerPayload: MapPickerPayload? = nil
    @Published var tempCoordinate: CLLocationCoordinate2D?
    @Published var showCamera = false
    @Published var previewRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671),
        span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
    )
    @Published var mapInitialQuery: String? = nil
    @Published var addressLine = ""

    @Published var scheduleOpenTime: String? = nil
    @Published var scheduleCloseTime: String? = nil
    @Published var scheduleLastEntryTime: String? = nil
    @Published var scheduleClosedWeekdays: [Weekday] = []
    @Published var scheduleHolidayHandling: HolidayHandling? = nil
    @Published var scheduleClosedDateRules: [DateRule] = []
    @Published var scheduleOpenDateRules: [DateRule] = []
    @Published var scheduleSpecialOpenings: [SpecialOpening] = []
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

    @Published var admissionFees: [AdmissionFeeRule] = []
    @Published var reservationRequired: Bool? = nil
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

    func handlePickedImage(_ image: UIImage, useAIExtraction: Bool) async {
        do {
            let result: FlyerExtractionResult
            var usedAI = false
            if useAIExtraction {
                isAIAnalyzing = true
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
                posterThumbData = thumb
            }
            if let dom = DominantColorService.dominantColor(from: image) {
                autoColor = dom
                pickedColor = Color(dom)
            }

            titleOptions = result.titleCandidates
            venueOptions = result.venueCandidates
            dateOptions = result.dateCandidates

            if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               let firstTitle = result.titleCandidates.first {
                title = firstTitle
            }

            if venue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               let firstVenue = result.venueCandidates.first {
                venue = firstVenue
            }

            if !hasManuallyEditedDates,
               let firstPeriod = result.dateCandidates.first {
                isApplyingAutoDates = true
                startDate = firstPeriod.0
                endDate = firstPeriod.1
                isApplyingAutoDates = false
            }

            if urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               let firstURL = result.urlCandidates.first {
                urlString = firstURL
            }

            let missingTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let missingVenue = venue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let missingDates = dateOptions.isEmpty

            if missingTitle || missingVenue || missingDates {
                showReviewSheet = true
            }
            if useAIExtraction {
                isAIAnalyzing = false
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
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
        } catch {
            if useAIExtraction {
                isAIAnalyzing = false
            }
            ocrAlertMessage = "ポスターの文字認識に失敗しました：\(error.localizedDescription)"
            showOcrAlert = true
        }
    }

    func autoResolveAddress(from venue: String) async {
        let trimmed = venue.trimmingCharacters(in: .whitespacesAndNewlines)
        print("📍 autoResolveAddress start: \"\(trimmed)\"")
        guard !trimmed.isEmpty else { return }
        guard addressLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("📍 address already filled, skip auto resolve")
            return
        }

        if let result = try? await VenueGeocodingService.geocodeWithAddress(trimmed) {
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
        } else {
            print("📍 geocodeWithAddress returned nil")
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
            } else {
                mapInitialQuery = v
            }
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
}
