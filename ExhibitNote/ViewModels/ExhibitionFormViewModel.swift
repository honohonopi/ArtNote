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
import PDFKit

@MainActor
final class ExhibitionFormViewModel: ObservableObject {
    @Published var title = ""
    @Published var venue = ""
    @Published var startDate = Date()
    @Published var endDate = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
    @Published var urlString: String = ""
    @Published var catalogTotalCountStr: String = ""

    @Published var showPhotoPicker = false
    @Published var selectedItems: [PhotosPickerItem] = []
    @Published var ocrAlertMessage: String? = nil
    @Published var showOcrAlert = false
    @Published var showFoundationModelUnavailableAlert = false
    @Published var showFoundationModelDontShowWarning = false
    @Published var showPDFPicker = false
    @Published var pdfSelection: PDFSelection? = nil

    @Published var titleOptions: [String] = []
    @Published var venueOptions: [String] = []
    @Published var dateOptions: [(Date, Date)] = []
    @Published var urlOptions: [String] = []

    @Published var selectedTitle: String?
    @Published var selectedVenue: String?
    @Published var selectedDateIndex: Int = 0
    @Published var selectedURL: String?
    @Published var hasManuallyEditedDates = false
    @Published var isApplyingAutoDates = false
    @Published var isAIAnalyzing = false
    @Published var isExtracting = false

    @Published var showReviewSheet = false
    @Published var showBasicOnlyNotice = false
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

    struct PDFSelection: Identifiable {
        let id = UUID()
        let url: URL
        let pageCount: Int
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

    func preparePickedPDF(_ url: URL) {
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed { url.stopAccessingSecurityScopedResource() }
        }
        guard let document = PDFDocument(url: url) else {
            ocrAlertMessage = "PDFの読み込みに失敗しました。"
            showOcrAlert = true
            return
        }
        if document.pageCount <= 1 {
            Task { await handlePickedPDF(url, pageIndex: 0) }
            return
        }
        pdfSelection = PDFSelection(url: url, pageCount: document.pageCount)
    }

    func handlePickedPDF(_ url: URL, pageIndex: Int) async {
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed { url.stopAccessingSecurityScopedResource() }
        }
        guard let document = PDFDocument(url: url),
              pageIndex >= 0,
              pageIndex < document.pageCount,
              let page = document.page(at: pageIndex),
              let image = renderPDFPage(page)
        else {
            ocrAlertMessage = "PDFの読み込みに失敗しました。"
            showOcrAlert = true
            return
        }
        await handlePickedImage(image)
    }

    func handlePickedPDF(_ url: URL, pageIndices: [Int]) async {
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed { url.stopAccessingSecurityScopedResource() }
        }
        guard let document = PDFDocument(url: url) else {
            ocrAlertMessage = "PDFの読み込みに失敗しました。"
            showOcrAlert = true
            return
        }
        let images: [UIImage] = pageIndices.compactMap { index in
            guard index >= 0, index < document.pageCount,
                  let page = document.page(at: index)
            else { return nil }
            return renderPDFPage(page, maxSide: 1600)
        }
        guard let combined = combineImagesVertically(images) else {
            ocrAlertMessage = "PDFの読み込みに失敗しました。"
            showOcrAlert = true
            return
        }
        await handlePickedImage(combined)
    }

    private func renderPDFPage(_ page: PDFPage, maxSide: CGFloat = 2000) -> UIImage? {
        let pageRect = page.bounds(for: .mediaBox)
        let scale = min(maxSide / max(pageRect.width, pageRect.height), 1)
        let size = CGSize(width: pageRect.width * scale, height: pageRect.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            context.cgContext.saveGState()
            context.cgContext.translateBy(x: 0, y: size.height)
            context.cgContext.scaleBy(x: scale, y: -scale)
            page.draw(with: .mediaBox, to: context.cgContext)
            context.cgContext.restoreGState()
        }
    }

    private func combineImagesVertically(_ images: [UIImage]) -> UIImage? {
        guard !images.isEmpty else { return nil }
        let maxWidth = min(images.map { $0.size.width }.max() ?? 0, 1600)
        let spacing: CGFloat = 12
        let sizes: [CGSize] = images.map { img in
            let scale = maxWidth / img.size.width
            return CGSize(width: maxWidth, height: img.size.height * scale)
        }
        let totalHeight = sizes.reduce(0) { $0 + $1.height } + spacing * CGFloat(max(0, sizes.count - 1))
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: maxWidth, height: totalHeight))
        return renderer.image { context in
            var y: CGFloat = 0
            for (idx, img) in images.enumerated() {
                let size = sizes[idx]
                img.draw(in: CGRect(origin: CGPoint(x: 0, y: y), size: size))
                y += size.height + spacing
            }
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
        guard let combined = combineImagesVertically(limited) else {
            ocrAlertMessage = "画像の読み込みに失敗しました。"
            showOcrAlert = true
            return
        }
        await handlePickedImage(combined)
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
