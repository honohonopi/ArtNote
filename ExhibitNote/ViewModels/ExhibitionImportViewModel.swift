import Combine
import Foundation

@MainActor
final class ExhibitionImportViewModel: ObservableObject {
    struct SpecialOpeningText {
        let main: String
        let lastEntry: String?
    }

    let payload: ExhibitionSharePayload

    @Published private(set) var posterThumbData: Data?
    @Published private(set) var isLoadingPoster = false

    private let importService: ExhibitionImportService

    init(
        payload: ExhibitionSharePayload,
        importService: ExhibitionImportService = ExhibitionImportService()
    ) {
        self.payload = payload
        self.importService = importService
    }

    var periodText: String {
        "\(formatYMD(payload.startDate)) ~ \(formatYMD(payload.endDate))"
    }

    var admissionFeesForDisplay: [AdmissionFeeRule] {
        payload.admissionFees.compactMap { fee in
            let label = fee.rawLabel.trimmingCharacters(in: .whitespacesAndNewlines)
            let note = fee.note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if label.isEmpty && fee.priceYen == nil && note.isEmpty {
                return nil
            }
            var cleaned = fee
            cleaned.rawLabel = label
            cleaned.note = note.isEmpty ? nil : note
            return cleaned
        }
    }

    func loadPosterThumbnail() async {
        guard posterThumbData == nil, !isLoadingPoster else { return }
        isLoadingPoster = true
        defer { isLoadingPoster = false }
        posterThumbData = await importService.loadPosterThumbnail(from: payload)
    }

    func makeExhibition() -> Exhibition {
        importService.makeExhibition(
            from: payload,
            posterThumbData: posterThumbData
        )
    }

    func weekdayLabel(_ weekdays: [String]) -> String {
        let labels = [
            "monday": "月",
            "tuesday": "火",
            "wednesday": "水",
            "thursday": "木",
            "friday": "金",
            "saturday": "土",
            "sunday": "日"
        ]
        return weekdays.compactMap { labels[$0.lowercased()] }.joined(separator: "・")
    }

    func holidayHandlingLabel(_ rawValue: String) -> String {
        switch rawValue.uppercased() {
        case "NONE":
            return "祝日対応なし"
        case "OPEN_ON_HOLIDAY":
            return "祝日は開館"
        case "OPEN_ON_HOLIDAY_CLOSE_NEXT_WEEKDAY":
            return "祝日開館・翌平日休館"
        default:
            return rawValue
        }
    }

    func dateRulesText(_ rules: [DateRuleRecord]) -> String {
        rules.map(dateRuleText).joined(separator: "\n")
    }

    func specialOpeningText(_ record: SpecialOpeningRecord) -> SpecialOpeningText {
        let label: String
        switch record.ruleType {
        case .date:
            label = record.date ?? ""
        case .weekday:
            if let weekday = record.weekday {
                label = "毎週\(weekdayLabel([weekday.rawValue]))"
            } else {
                label = ""
            }
        case .range:
            if let startDate = record.startDate, let endDate = record.endDate {
                label = "\(startDate)〜\(endDate)"
            } else {
                label = ""
            }
        }

        let time = "\(record.openTime)〜\(record.closeTime)"
        let main = "\(label) \(time)".trimmingCharacters(in: .whitespacesAndNewlines)
        let lastEntry = record.lastEntryTime?.trimmingCharacters(in: .whitespacesAndNewlines)
        return SpecialOpeningText(
            main: main,
            lastEntry: lastEntry.flatMap { $0.isEmpty ? nil : "最終入場 \($0)" }
        )
    }

    private func formatYMD(_ value: String) -> String {
        let rawValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = rawValue.split(separator: "-")
        guard parts.count == 3 else {
            return rawValue.replacingOccurrences(of: "-", with: "/")
        }

        let year = parts[0]
        let month = parts[1].count == 1 ? "0\(parts[1])" : String(parts[1])
        let day = parts[2].count == 1 ? "0\(parts[2])" : String(parts[2])
        return "\(year)/\(month)/\(day)"
    }

    private func dateRuleText(_ rule: DateRuleRecord) -> String {
        switch rule.ruleType {
        case .date:
            return rule.date ?? ""
        case .range:
            guard let startDate = rule.startDate, let endDate = rule.endDate else { return "" }
            return "\(startDate)〜\(endDate)"
        }
    }
}
