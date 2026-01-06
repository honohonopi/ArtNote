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
            dateCandidates = DateParsingService.candidates(from: text)
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
        let holidayHandling = parseHolidayHandling(regular.holidayHandling) ?? .none

        var closedDates = (payload.exceptions?.closedDates ?? [])
            .compactMap { ISODateParser.parseISODate($0) }
        var openDates = (payload.exceptions?.openDates ?? [])
            .compactMap { ISODateParser.parseISODate($0) }
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
                            openDates.append(date)
                        } else if containsClosedKeyword(note) {
                            closedDates.append(date)
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
           closedDates.isEmpty,
           openDates.isEmpty,
           specialOpenings.isEmpty {
            return nil
        }

        let uniqClosed = uniqueDates(closedDates)
        let uniqOpen = uniqueDates(openDates)

        return ScheduleExtraction(
            openTime: openTime,
            closeTime: closeTime,
            lastEntryTime: lastEntryTime,
            closedWeekdays: closedWeekdays,
            holidayHandling: holidayHandling,
            closedDates: uniqClosed,
            openDates: uniqOpen,
            specialOpenings: specialOpenings
        )
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

    private static func uniqueDates(_ dates: [Date]) -> [Date] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        formatter.dateFormat = "yyyy-MM-dd"
        var seen = Set<String>()
        var result: [Date] = []
        for date in dates {
            let key = formatter.string(from: date)
            if seen.insert(key).inserted {
                result.append(date)
            }
        }
        return result
    }
}
