import SwiftUI
import Observation
import PhotosUI
import UIKit

@MainActor
@Observable
final class ExhibitionFormViewModel {
    let draft = ExhibitionDraft()

    var showPhotoPicker = false
    var selectedItems: [PhotosPickerItem] = []
    var showCamera = false
    var showPDFPicker = false
    var pdfSelection: PDFSelection?

    var ocrAlertMessage: String?
    var showOcrAlert = false
    var showFoundationModelUnavailableAlert = false
    var showFoundationModelDontShowWarning = false
    var isAIAnalyzing = false
    var isExtracting = false

    var titleOptions: [String] = []
    var venueOptions: [String] = []
    var dateOptions: [(Date, Date)] = []
    var urlOptions: [String] = []
    var selectedTitle: String?
    var selectedVenue: String?
    var selectedDateIndex = 0
    var selectedURL: String?
    var showReviewSheet = false
    var showBasicOnlyNotice = false
    var showMissingAlert = false
    var missingAlertMessage = ""
    var pendingAlertMessage: String?

    struct PDFSelection: Identifiable {
        let id = UUID()
        let url: URL
        let pageCount: Int
    }

    func preparePickedPDF(_ url: URL) {
        guard let pageCount = FlyerImageService.pdfPageCount(at: url) else {
            showPDFError()
            return
        }
        if pageCount <= 1 {
            Task { await handlePickedPDF(url, pageIndex: 0) }
        } else {
            pdfSelection = PDFSelection(url: url, pageCount: pageCount)
        }
    }

    func handlePickedPDF(_ url: URL, pageIndex: Int) async {
        guard let image = FlyerImageService.image(fromPDF: url, pageIndex: pageIndex) else {
            showPDFError()
            return
        }
        await handlePickedImage(image)
    }

    func handlePickedPDF(_ url: URL, pageIndices: [Int]) async {
        guard let image = FlyerImageService.combinedImage(fromPDF: url, pageIndices: pageIndices) else {
            showPDFError()
            return
        }
        await handlePickedImage(image)
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
                result = try await TextRecognitionService.extractFlyerFieldsWithMeta(from: image, basicOnly: true).result
                showBasicOnlyNotice = true
                checkFoundationModelAvailability()
            }

            draft.applyPosterAppearance(from: image)
            applyCandidates(from: result)
            isAIAnalyzing = false
            UIImpactFeedbackGenerator(style: .light).impactOccurred()

            if usedAI {
                if let venue = result.venuePOI ?? result.venueCandidates.first {
                    await draft.autoResolveAddress(from: venue)
                }
                applyDetailedExtraction(result)
            } else if let venue = result.venueCandidates.first {
                await draft.autoResolveAddress(from: venue)
            }
        } catch {
            isAIAnalyzing = false
            ocrAlertMessage = "ポスターの文字認識に失敗しました：\(error.localizedDescription)"
            showOcrAlert = true
        }
    }

    func handlePickedImages(_ images: [UIImage]) async {
        guard !images.isEmpty else { return }
        if images.count == 1, let image = images.first {
            await handlePickedImage(image)
            return
        }
        guard let image = FlyerImageService.combineVertically(Array(images.prefix(2))) else {
            ocrAlertMessage = "画像の読み込みに失敗しました。"
            showOcrAlert = true
            return
        }
        await handlePickedImage(image)
    }

    func handleSelectedPhotoItems(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        defer { selectedItems = [] }
        var images: [UIImage] = []
        for item in items.prefix(2) {
            if let image = await item.loadUIImage() { images.append(image) }
        }
        guard !images.isEmpty else {
            ocrAlertMessage = "画像の読み込みに失敗しました。"
            showOcrAlert = true
            return
        }
        await handlePickedImages(images)
    }

    func makeExhibition() -> Exhibition {
        draft.makeExhibition()
    }

    func suppressFoundationModelAlert() {
        UserDefaults.standard.set(true, forKey: "foundationModelUnavailableDontShow")
        showFoundationModelUnavailableAlert = false
        showFoundationModelDontShowWarning = true
    }

    private func applyCandidates(from result: FlyerExtractionResult) {
        titleOptions = result.titleCandidates
        venueOptions = result.venueCandidates
        dateOptions = result.dateCandidates
        urlOptions = result.urlCandidates

        if draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let title = result.titleCandidates.first {
            draft.title = title
        }
        if draft.venue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let venue = result.venueCandidates.first {
            draft.venue = venue
        }
        if !draft.hasManuallyEditedDates, let period = result.dateCandidates.first {
            draft.isApplyingAutoDates = true
            draft.startDate = period.0
            draft.endDate = period.1
            draft.isApplyingAutoDates = false
        }
        if draft.urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let url = result.urlCandidates.first {
            draft.urlString = url
        }
        selectedURL = draft.urlString.isEmpty ? nil : draft.urlString

        let isMissingRequiredValue = draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            draft.venue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            dateOptions.isEmpty
        let hasMultipleCandidates = [titleOptions.count, venueOptions.count, dateOptions.count, urlOptions.count]
            .contains { $0 > 1 }
        if isMissingRequiredValue || hasMultipleCandidates {
            showReviewSheet = true
        }
    }

    private func applyDetailedExtraction(_ result: FlyerExtractionResult) {
        if let schedule = result.schedule {
            draft.scheduleOpenTime = schedule.openTime
            draft.scheduleCloseTime = schedule.closeTime
            draft.scheduleLastEntryTime = schedule.lastEntryTime
            draft.scheduleClosedWeekdays = schedule.closedWeekdays
            draft.scheduleHolidayHandling = schedule.holidayHandling
            draft.scheduleClosedDateRules = schedule.closedDateRules
            draft.scheduleOpenDateRules = schedule.openDateRules.filter {
                if case .date = $0.rule { return true }
                return false
            }
            draft.scheduleSpecialOpenings = schedule.specialOpenings
        } else {
            draft.scheduleOpenTime = nil
            draft.scheduleCloseTime = nil
            draft.scheduleLastEntryTime = nil
            draft.scheduleClosedWeekdays = []
            draft.scheduleHolidayHandling = nil
            draft.scheduleClosedDateRules = []
            draft.scheduleOpenDateRules = []
            draft.scheduleSpecialOpenings = []
        }
        if let fees = result.admissionFees, !fees.isEmpty { draft.admissionFees = fees }
        if let reservation = result.reservationRequired { draft.reservationRequired = reservation }
    }

    private func checkFoundationModelAvailability() {
        guard #available(iOS 26.0, *),
              !UserDefaults.standard.bool(forKey: "foundationModelUnavailableDontShow"),
              !FoundationModelFlyerClassifier.isAvailable,
              FoundationModelFlyerClassifier.isSupportedButDisabled()
        else { return }
        showFoundationModelUnavailableAlert = true
    }

    private func showPDFError() {
        ocrAlertMessage = "PDFの読み込みに失敗しました。"
        showOcrAlert = true
    }
}
