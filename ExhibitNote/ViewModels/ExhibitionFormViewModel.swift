//
//  ExhibitionFormViewModel.swift
//  ExhibitNote
//
//  Created by Honoka Nishiyama on 2026/01/06.
//

import SwiftUI
import Observation
import MapKit
import PhotosUI
import UIKit

@MainActor
@Observable
final class ExhibitionFormViewModel {
    var title = ""
    var venue = ""
    var startDate = Date()
    var endDate = Calendar.japan.date(byAdding: .day, value: 30, to: Date()) ?? Date()
    var urlString: String = ""
    var catalogTotalCountStr: String = ""

    var showPhotoPicker = false
    var selectedItems: [PhotosPickerItem] = []
    var ocrAlertMessage: String? = nil
    var showOcrAlert = false
    var showFoundationModelUnavailableAlert = false
    var showFoundationModelDontShowWarning = false
    var showPDFPicker = false
    var pdfSelection: PDFSelection? = nil

    var titleOptions: [String] = []
    var venueOptions: [String] = []
    var dateOptions: [(Date, Date)] = []
    var urlOptions: [String] = []

    var selectedTitle: String?
    var selectedVenue: String?
    var selectedDateIndex: Int = 0
    var selectedURL: String?
    var hasManuallyEditedDates = false
    var isApplyingAutoDates = false
    var isAIAnalyzing = false
    var isExtracting = false

    var showReviewSheet = false
    var showBasicOnlyNotice = false
    var showMissingAlert = false
    var missingAlertMessage: String = ""
    var pendingAlertMessage: String? = nil

    var pickedColor: Color? = nil
    var autoColor: UIColor? = nil
    var posterThumbData: Data? = nil

    var showMapPicker = false
    var tempCoordinate: CLLocationCoordinate2D?
    var showCamera = false
    var previewRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671),
        span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
    )
    var addressLine = ""

    var scheduleOpenTime: String? = nil
    var scheduleCloseTime: String? = nil
    var scheduleLastEntryTime: String? = nil
    var scheduleClosedWeekdays: [Weekday] = []
    var scheduleHolidayHandling: HolidayHandling? = nil
    var scheduleClosedDateRules: [DateRule] = []
    var scheduleOpenDateRules: [DateRule] = []
    var scheduleSpecialOpenings: [SpecialOpening] = []
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

    var admissionFees: [AdmissionFeeRule] = []
    var reservationRequired: Bool? = nil
    var showAdmissionFees = false
    var showAdmissionFeeEditor = false
    var editingAdmissionFeeIndex: Int? = nil
    var draftAdmissionLabel: String = ""
    var draftAdmissionPriceText: String = ""
    var draftAdmissionNote: String = ""
    var draftAdmissionTargets: [UserTicketCategory] = []

    struct PDFSelection: Identifiable {
        let id = UUID()
        let url: URL
        let pageCount: Int
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

    func preparePickedPDF(_ url: URL) {
        guard let pageCount = FlyerImageService.pdfPageCount(at: url) else {
            ocrAlertMessage = "PDFの読み込みに失敗しました。"
            showOcrAlert = true
            return
        }
        if pageCount <= 1 {
            Task { await handlePickedPDF(url, pageIndex: 0) }
            return
        }
        pdfSelection = PDFSelection(url: url, pageCount: pageCount)
    }

    func handlePickedPDF(_ url: URL, pageIndex: Int) async {
        guard let image = FlyerImageService.image(fromPDF: url, pageIndex: pageIndex) else {
            ocrAlertMessage = "PDFの読み込みに失敗しました。"
            showOcrAlert = true
            return
        }
        await handlePickedImage(image)
    }

    func handlePickedPDF(_ url: URL, pageIndices: [Int]) async {
        guard let combined = FlyerImageService.combinedImage(
            fromPDF: url,
            pageIndices: pageIndices
        ) else {
            ocrAlertMessage = "PDFの読み込みに失敗しました。"
            showOcrAlert = true
            return
        }
        await handlePickedImage(combined)
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

    func handlePickedImage(_ image: UIImage) async {
        do {
            let result: FlyerExtractionResult
            var usedAI = false
            isExtracting = true
            showBasicOnlyNotice = false
            defer { isExtracting = false }
            isAIAnalyzing = true
            do {
                result = try await TextRecognitionService.extractFlyerFieldsWithAI(from: image)
                usedAI = true
            } catch {
                let fallback = try await TextRecognitionService.extractFlyerFieldsWithMeta(from: image, basicOnly: true)
                result = fallback.result
                usedAI = false
                showBasicOnlyNotice = true
                checkFoundationModelAvailability()
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
            urlOptions = result.urlCandidates

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
            selectedURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : urlString

            let missingTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let missingVenue = venue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let missingDates = dateOptions.isEmpty
            let hasMultipleCandidates = titleOptions.count > 1 ||
                venueOptions.count > 1 ||
                dateOptions.count > 1 ||
                urlOptions.count > 1

            if missingTitle || missingVenue || missingDates || hasMultipleCandidates {
                showReviewSheet = true
            }
            isAIAnalyzing = false
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()

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
            } else if addressLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      let firstVenue = result.venueCandidates.first,
                      !firstVenue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                await autoResolveAddress(from: firstVenue)
            }

            if usedAI {
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
            isAIAnalyzing = false
            isExtracting = false
            ocrAlertMessage = "ポスターの文字認識に失敗しました：\(error.localizedDescription)"
            showOcrAlert = true
        }
    }

    private func checkFoundationModelAvailability() {
        guard #available(iOS 26.0, *) else { return }
        let suppressKey = "foundationModelUnavailableDontShow"
        if UserDefaults.standard.bool(forKey: suppressKey) { return }
        if !FoundationModelFlyerClassifier.isAvailable,
           FoundationModelFlyerClassifier.isSupportedButDisabled() {
            showFoundationModelUnavailableAlert = true
        }
    }

    func suppressFoundationModelAlert() {
        UserDefaults.standard.set(true, forKey: "foundationModelUnavailableDontShow")
        showFoundationModelUnavailableAlert = false
        showFoundationModelDontShowWarning = true
    }

    func handlePickedImages(_ images: [UIImage]) async {
        guard !images.isEmpty else { return }
        if images.count == 1, let first = images.first {
            await handlePickedImage(first)
            return
        }
        let limited = Array(images.prefix(2))
        guard let combined = FlyerImageService.combineVertically(limited) else {
            ocrAlertMessage = "画像の読み込みに失敗しました。"
            showOcrAlert = true
            return
        }
        await handlePickedImage(combined)
    }

    func handleSelectedPhotoItems(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        defer { selectedItems = [] }

        var images: [UIImage] = []
        for item in items.prefix(2) {
            if let image = await item.loadUIImage() {
                images.append(image)
            }
        }

        guard !images.isEmpty else {
            ocrAlertMessage = "画像の読み込みに失敗しました。"
            showOcrAlert = true
            return
        }
        await handlePickedImages(images)
    }

    func makeExhibition() -> Exhibition {
        let exhibition = Exhibition(
            title: title,
            venue: venue,
            address: addressLine.trimmingCharacters(in: .whitespacesAndNewlines),
            startDate: startDate,
            endDate: endDate,
            url: urlString.normalizedWebURL(),
            catalogTotalCount: Int(catalogTotalCountStr.trimmingCharacters(in: .whitespacesAndNewlines))
        )
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

        if let coordinate = tempCoordinate {
            exhibition.setCoordinate(coordinate)
        }
        if let color = pickedColor.map(UIColor.init) ?? autoColor {
            exhibition.setColor(color)
        }
        return exhibition
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

    private static func holidayHandlingRawValue(_ value: HolidayHandling) -> String {
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
