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

        let closedDates = (payload.exceptions?.closedDates ?? [])
            .compactMap { ISODateParser.parseISODate($0) }
        let openDates = (payload.exceptions?.openDates ?? [])
            .compactMap { ISODateParser.parseISODate($0) }
        let specialOpenings = (payload.exceptions?.specialOpenings ?? [])
            .compactMap { entry -> SpecialOpening? in
                guard let dateStr = entry.date?.trimmed, !dateStr.isEmpty else { return nil }
                if let weekday = parseWeekdayRule(dateStr) {
                    return SpecialOpening(
                        rule: .weekday(weekday),
                        openTime: entry.openTime ?? "",
                        closeTime: entry.closeTime ?? "",
                        lastEntryTime: entry.lastEntryTime,
                        note: entry.note
                    )
                }
                guard let date = ISODateParser.parseISODate(dateStr) else { return nil }
                return SpecialOpening(
                    rule: .date(date),
                    openTime: entry.openTime ?? "",
                    closeTime: entry.closeTime ?? "",
                    lastEntryTime: entry.lastEntryTime,
                    note: entry.note
                )
            }

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

        return ScheduleExtraction(
            openTime: openTime,
            closeTime: closeTime,
            lastEntryTime: lastEntryTime,
            closedWeekdays: closedWeekdays,
            holidayHandling: holidayHandling,
            closedDates: closedDates,
            openDates: openDates,
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
}
