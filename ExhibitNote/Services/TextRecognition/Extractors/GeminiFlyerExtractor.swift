//
//  GeminiFlyerExtractor.swift
//  ExhibitNote
//
//  Created by Honoka Nishiyama on 2026/01/06.
//

import Foundation
import GoogleGenerativeAI
import UIKit

enum GeminiFlyerExtractor {

    static func extract(from image: UIImage) async throws -> FlyerExtractionResult {
        let model = GenerativeModel(name: "gemini-2.5-flash-lite", apiKey: APIKey.default)
        let response = try await model.generateContent(GeminiPrompts.flyerBasic, image)
        let text = response.text ?? ""
        print("🤖 AI raw response: \(text)")
        guard let json = JSONSnippetExtractor.extractFirstJSON(from: text),
              let data = json.data(using: .utf8) else {
            throw TextRecognitionError.aiResponseInvalid
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let payload = try decoder.decode(GeminiFlyerResponse.self, from: data)

        let titleCandidates = [payload.title?.trimmed].compactMap { $0 }.filter { !$0.isEmpty }
        let venueCandidates = [payload.venue?.trimmed].compactMap { $0 }.filter { !$0.isEmpty }
        let venuePOI = payload.venuePoi?.trimmed
        let urlCandidates = [payload.url?.trimmed].compactMap { $0 }.filter { !$0.isEmpty }
        let admissionFees: [AdmissionFeeRule]? = {
            guard let fees = payload.admission?.fees else { return nil }
            return GeminiAdmissionMapper.mapFees(fees)
        }()
        let reservationRequired = payload.reservation?.required

        let schedule = buildSchedule(from: payload)
        let period = payload.period

        var dateCandidates: [(Date, Date)] = []
        if let start = period?.startDate.flatMap(ISODateParser.parseISODate),
           let end = period?.endDate.flatMap(ISODateParser.parseISODate) {
            dateCandidates = [(start, end)]
        } else if let text = period?.periodText?.trimmed, !text.isEmpty {
            dateCandidates = DateExtractor.candidates(from: text)
        }

        let rawText = [
            payload.title,
            payload.venue,
            payload.venuePoi,
            period?.periodText,
            period?.startDate,
            period?.endDate,
            payload.url
        ]
        .compactMap { $0?.trimmed }
        .filter { !$0.isEmpty }
        .joined(separator: "\n")

        return FlyerExtractionResult(
            rawText: rawText,
            classifiedLines: [],
            titleCandidates: titleCandidates,
            venueCandidates: venueCandidates,
            venuePOI: venuePOI,
            schedule: schedule,
            dateCandidates: dateCandidates,
            urlCandidates: urlCandidates,
            admissionFees: admissionFees,
            reservationRequired: reservationRequired
        )
    }

    private static func buildSchedule(from payload: GeminiFlyerResponse) -> ScheduleExtraction? {
        guard let regular = payload.regularSchedule else { return nil }
        let openTime = regular.openTime?.trimmed
        let closeTime = regular.closeTime?.trimmed
        let lastEntryTime = regular.lastEntryTime?.trimmed
        let closedWeekdays = (regular.closedWeekdays ?? [])
            .compactMap { Weekday(rawValue: $0.lowercased()) }
        let holidayHandling = parseHolidayHandling(regular.holidayHandling)

        var closedDateRules = parseDateRules(payload.exceptions?.closedRules, allowRange: true)
        var openDateRules = parseDateRules(payload.exceptions?.openRules, allowRange: false)
        let legacyClosedDates = (payload.exceptions?.closedDates ?? [])
            .compactMap { ISODateParser.parseISODate($0) }
        let legacyOpenDates = (payload.exceptions?.openDates ?? [])
            .compactMap { ISODateParser.parseISODate($0) }
        closedDateRules.append(contentsOf: legacyClosedDates.map { DateRule(rule: .date($0), note: nil) })
        openDateRules.append(contentsOf: legacyOpenDates.map { DateRule(rule: .date($0), note: nil) })
        let specialOpenings = (payload.exceptions?.specialOpenings ?? [])
            .compactMap { entry -> SpecialOpening? in
                let openTime = entry.openTime?.trimmed ?? ""
                let closeTime = entry.closeTime?.trimmed ?? ""
                let note = entry.note?.trimmed ?? ""
                guard let ruleType = entry.ruleType?.trimmed.lowercased(),
                      ["date", "weekday", "range"].contains(ruleType) else {
                    return nil
                }

                switch ruleType {
                case "range":
                    guard let startStr = entry.startDate?.trimmed,
                          let endStr = entry.endDate?.trimmed,
                          let start = ISODateParser.parseISODate(startStr),
                          let end = ISODateParser.parseISODate(endStr)
                    else { return nil }
                    guard !openTime.isEmpty, !closeTime.isEmpty else { return nil }
                    return SpecialOpening(
                        rule: .range(start: start, end: end),
                        openTime: openTime,
                        closeTime: closeTime,
                        lastEntryTime: entry.lastEntryTime,
                        note: entry.note
                    )
                case "weekday":
                    guard let dateStr = entry.date?.trimmed,
                          let weekday = parseWeekdayRule(dateStr)
                    else { return nil }
                    guard !openTime.isEmpty, !closeTime.isEmpty else { return nil }
                    return SpecialOpening(
                        rule: .weekday(weekday),
                        openTime: openTime,
                        closeTime: closeTime,
                        lastEntryTime: entry.lastEntryTime,
                        note: entry.note
                    )
                case "date":
                    guard let dateStr = entry.date?.trimmed,
                          let date = ISODateParser.parseISODate(dateStr)
                    else { return nil }

                if openTime.isEmpty || closeTime.isEmpty {
                    if containsOpenKeyword(note) {
                        openDateRules.append(DateRule(rule: .date(date), note: entry.note))
                    } else if containsClosedKeyword(note) {
                        closedDateRules.append(DateRule(rule: .date(date), note: entry.note))
                    }
                    return nil
                }

                    return SpecialOpening(
                        rule: .date(date),
                        openTime: openTime,
                        closeTime: closeTime,
                        lastEntryTime: entry.lastEntryTime,
                        note: entry.note
                    )
                default:
                    return nil
                }
            }
            .filter { isValidSpecialOpening($0) }

        if openTime == nil,
           closeTime == nil,
           lastEntryTime == nil,
           closedWeekdays.isEmpty,
           holidayHandling == nil,
           closedDateRules.isEmpty,
           openDateRules.isEmpty,
           specialOpenings.isEmpty {
            return nil
        }

        let uniqClosed = uniqueDateRules(closedDateRules)
        let uniqOpen = uniqueDateRules(openDateRules)

        return ScheduleExtraction(
            openTime: openTime,
            closeTime: closeTime,
            lastEntryTime: lastEntryTime,
            closedWeekdays: closedWeekdays,
            holidayHandling: holidayHandling,
            closedDateRules: uniqClosed,
            openDateRules: uniqOpen,
            specialOpenings: specialOpenings
        )
    }

    private static func parseDateRules(
        _ rules: [GeminiDateRule]?,
        allowRange: Bool
    ) -> [DateRule] {
        guard let rules else { return [] }
        return rules.compactMap { rule in
            let ruleType = rule.ruleType?.trimmed.lowercased()
            if allowRange, ruleType == "range",
               let startStr = rule.startDate?.trimmed,
               let endStr = rule.endDate?.trimmed,
               let start = ISODateParser.parseISODate(startStr),
               let end = ISODateParser.parseISODate(endStr) {
                return DateRule(rule: .range(start: start, end: end), note: rule.note)
            }
            if ruleType == "date" || ruleType == nil,
               let dateStr = rule.date?.trimmed,
               let date = ISODateParser.parseISODate(dateStr) {
                return DateRule(rule: .date(date), note: rule.note)
            }
            return nil
        }
    }

    private static func uniqueDateRules(_ rules: [DateRule]) -> [DateRule] {
        var seen: Set<String> = []
        return rules.filter { rule in
            let key: String
            switch rule.rule {
            case .date(let date):
                key = "date:\(ScheduleDateKey.format(date))"
            case .range(let start, let end):
                key = "range:\(ScheduleDateKey.format(start))-\(ScheduleDateKey.format(end))"
            }
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
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

    private static func parseWeekdayRule(_ value: String) -> Weekday? {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if normalized.hasPrefix("EVERY_") {
            let raw = normalized.replacingOccurrences(of: "EVERY_", with: "")
            return Weekday(rawValue: raw.lowercased())
        }
        return nil
    }

    private static func isValidSpecialOpening(_ opening: SpecialOpening) -> Bool {
        let noteText = opening.note?.lowercased() ?? ""
        if containsEventKeyword(noteText) || containsClosedKeyword(noteText) {
            return false
        }
        let hasOpen = !opening.openTime.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasClose = !opening.closeTime.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return hasOpen && hasClose
    }

    private static func containsEventKeyword(_ text: String) -> Bool {
        let keywords = [
            "展示解説", "ギャラリートーク", "トーク", "講演", "講座",
            "ワークショップ", "イベント", "レクチャー"
        ]
        return keywords.contains { text.contains($0) }
    }

    private static func containsClosedKeyword(_ text: String) -> Bool {
        let keywords = ["休館", "休室", "休園", "closed"]
        return keywords.contains { text.contains($0) }
    }

    private static func containsOpenKeyword(_ text: String) -> Bool {
        let keywords = ["開館", "open", "祝"]
        return keywords.contains { text.contains($0) }
    }

    private enum ScheduleDateKey {
        static let formatter: DateFormatter = {
            let formatter = DateFormatter.japanese()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = Calendar.japan.timeZone
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter
        }()

        static func format(_ date: Date) -> String {
            formatter.string(from: date)
        }
    }

}
