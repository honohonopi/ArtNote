//
//  ScheduleParser.swift
//  ExhibitNote
//
//  Created by Codex on 2026/01/xx.
//

import Foundation

enum ScheduleParser {
    static func parse(
        from text: String,
        closedSource: String,
        specialClosedSource: String,
        specialOpenSource: String,
        specialOpeningTimeSource: String
    ) -> ScheduleExtraction? {
        let time = parseTimeRange(from: text)
        let closedWeekdayStrings = parseClosedWeekdays(from: closedSource + "\n" + text)
        let holidayHandlingRaw = parseHolidayHandling(from: closedSource + "\n" + text)
        let specialClosedRecords = parseSpecialClosedDates(from: specialClosedSource)
        let specialOpenRecords = parseSpecialOpenDates(from: specialOpenSource)
        let specialTimeRecords = parseSpecialOpeningTimes(from: specialOpeningTimeSource)
        let closedWeekdays = closedWeekdayStrings.compactMap { Weekday(rawValue: $0) }
        let holidayHandling = holidayHandlingRaw.flatMap { HolidayHandling(rawValue: $0) }
        let closedRules = specialClosedRecords.compactMap { $0.toDateRule() }
        let openRules = specialOpenRecords.compactMap { $0.toDateRule() }
        let specialOpenings = specialTimeRecords.compactMap { $0.toSpecialOpening() }
        if time == nil &&
            closedWeekdays.isEmpty &&
            holidayHandling == nil &&
            closedRules.isEmpty &&
            openRules.isEmpty &&
            specialOpenings.isEmpty {
            return nil
        }
        return ScheduleExtraction(
            openTime: time?.open,
            closeTime: time?.close,
            lastEntryTime: time?.lastEntry,
            closedWeekdays: closedWeekdays,
            holidayHandling: holidayHandling,
            closedDateRules: closedRules,
            openDateRules: openRules,
            specialOpenings: specialOpenings
        )
    }

    private static func parseTimeRange(from text: String) -> (open: String, close: String, lastEntry: String?)? {
        let pattern = #"(?:開館時間|開館)?\s*([0-9]{1,2}:[0-9]{2})\s*[〜\-~]\s*([0-9]{1,2}:[0-9]{2})"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let openRange = Range(match.range(at: 1), in: text),
              let closeRange = Range(match.range(at: 2), in: text)
        else { return nil }
        let open = String(text[openRange])
        let close = String(text[closeRange])
        let lastEntry = parseLastEntry(from: text)
        return (open, close, lastEntry)
    }

    private static func parseLastEntry(from text: String) -> String? {
        let pattern = #"最終入場[:：]?\s*([0-9]{1,2}:[0-9]{2})"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let timeRange = Range(match.range(at: 1), in: text)
        else { return nil }
        return String(text[timeRange])
    }

    private static func parseClosedWeekdays(from text: String) -> [String] {
        let normalized = text.replacingOccurrences(of: " ", with: "")
        let map: [String: String] = [
            "月": "monday",
            "火": "tuesday",
            "水": "wednesday",
            "木": "thursday",
            "金": "friday",
            "土": "saturday",
            "日": "sunday"
        ]
        var results: [String] = []
        if normalized.contains("休館") || normalized.contains("休館日") || normalized.contains("休館曜日") {
            for (jp, en) in map {
                if normalized.contains(jp) {
                    results.append(en)
                }
            }
        }
        return results
    }

    private static func parseHolidayHandling(from text: String) -> String? {
        let normalized = text.replacingOccurrences(of: " ", with: "")
        if normalized.contains("祝日開館") || normalized.contains("祝日は開館") {
            return "OPEN_ON_HOLIDAY"
        }
        if normalized.contains("祝日休館") || normalized.contains("祝日は休館") {
            return "NONE"
        }
        if normalized.contains("祝日開館") && normalized.contains("翌平日休館") {
            return "OPEN_ON_HOLIDAY_CLOSE_NEXT_WEEKDAY"
        }
        return nil
    }

    private static func parseSpecialClosedDates(from text: String) -> [DateRuleRecord] {
        let dates = extractDates(from: text)
        return dates.map { DateRuleRecord(ruleType: .date, date: $0, startDate: nil, endDate: nil) }
    }

    private static func parseSpecialOpenDates(from text: String) -> [DateRuleRecord] {
        let dates = extractDates(from: text)
        return dates.map { DateRuleRecord(ruleType: .date, date: $0, startDate: nil, endDate: nil) }
    }

    private static func parseSpecialOpeningTimes(from text: String) -> [SpecialOpeningRecord] {
        let ranges = extractDateTimeRanges(from: text)
        return ranges.map { item in
            SpecialOpeningRecord(
                ruleType: .date,
                date: item.date,
                startDate: nil,
                endDate: nil,
                weekday: nil,
                openTime: item.open,
                closeTime: item.close,
                lastEntryTime: item.lastEntry
            )
        }
    }

    private static func extractDates(from text: String) -> [String] {
        let pattern = #"(20[0-9]{2})[-/\.](\d{1,2})[-/\.](\d{1,2})"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard let y = Range(match.range(at: 1), in: text),
                  let m = Range(match.range(at: 2), in: text),
                  let d = Range(match.range(at: 3), in: text)
            else { return nil }
            let month = text[m].count == 1 ? "0\(text[m])" : String(text[m])
            let day = text[d].count == 1 ? "0\(text[d])" : String(text[d])
            return "\(text[y])-\(month)-\(day)"
        }
    }

    private static func extractDateTimeRanges(from text: String) -> [(date: String, open: String, close: String, lastEntry: String?)] {
        let datePattern = #"(20[0-9]{2})[-/\.](\d{1,2})[-/\.](\d{1,2}).*?([0-9]{1,2}:[0-9]{2})\s*[〜\-~]\s*([0-9]{1,2}:[0-9]{2})"#
        guard let regex = try? NSRegularExpression(pattern: datePattern) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard let y = Range(match.range(at: 1), in: text),
                  let m = Range(match.range(at: 2), in: text),
                  let d = Range(match.range(at: 3), in: text),
                  let openRange = Range(match.range(at: 4), in: text),
                  let closeRange = Range(match.range(at: 5), in: text)
            else { return nil }
            let month = text[m].count == 1 ? "0\(text[m])" : String(text[m])
            let day = text[d].count == 1 ? "0\(text[d])" : String(text[d])
            let date = "\(text[y])-\(month)-\(day)"
            let open = String(text[openRange])
            let close = String(text[closeRange])
            let lastEntry = parseLastEntry(from: text)
            return (date, open, close, lastEntry)
        }
    }
}
