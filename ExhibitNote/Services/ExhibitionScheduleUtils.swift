//
//  ExhibitionScheduleUtils.swift
//  ArtNote
//
//  Created by Honoka Nishiyama on 2026/01/05.
//

import Foundation

enum OpeningStatus {
    case open(openTime: String, closeTime: String, lastEntryTime: String?)
    case closed
}

enum ExhibitionScheduleUtils {
    /// 日本の祝日判定（振替休日を含む）
    static func isJapaneseHoliday(_ date: Date) -> Bool {
        let cal = Calendar.japan
        // NOTE: Calendar.Component.isHoliday が未提供の SDK では常に false になります。
        // iOS 18 SDK で利用可能になったら .isHoliday を含めて判定してください。
        _ = cal
        _ = date
        return false
    }
    
    /// 指定日から次の平日を返す（週末・祝日をスキップ）
    static func nextBusinessDay(after date: Date) -> Date {
        let cal = Calendar.japan
        var cursor = cal.startOfDay(for: date)
        while true {
            guard let next = cal.date(byAdding: .day, value: 1, to: cursor) else { return cursor }
            cursor = next
            if isBusinessDay(cursor) { return cursor }
        }
    }
    
    static func openingStatus(on date: Date, exhibition: Exhibition) -> OpeningStatus {
        let cal = Calendar.japan
        let day = cal.startOfDay(for: date)
        
        if day < cal.startOfDay(for: exhibition.startDate) ||
            day > cal.startOfDay(for: exhibition.endDate) {
            return .closed
        }
        
        if let special = matchSpecialOpening(exhibition.scheduleSpecialOpenings, day, cal) {
            return .open(openTime: special.openTime,
                         closeTime: special.closeTime,
                         lastEntryTime: special.lastEntryTime)
        }
        
        if matchesDateRule(exhibition.scheduleClosedDateRules, day, cal) {
            return .closed
        }

        if matchesDateRule(exhibition.scheduleOpenDateRules, day, cal) {
            return .open(openTime: exhibition.scheduleOpenTime ?? "未設定",
                         closeTime: exhibition.scheduleCloseTime ?? "未設定",
                         lastEntryTime: exhibition.scheduleLastEntryTime)
        }
        
        let holidayHandling = holidayHandling(from: exhibition.scheduleHolidayHandling)
        let isHoliday = isJapaneseHoliday(day)
        if isHoliday {
            switch holidayHandling ?? .none {
            case .none:
                break
            case .openOnHoliday, .openOnHolidayCloseNextWeekday:
                return .open(openTime: exhibition.scheduleOpenTime ?? "未設定",
                             closeTime: exhibition.scheduleCloseTime ?? "未設定",
                             lastEntryTime: exhibition.scheduleLastEntryTime)
            }
        }
        
        if holidayHandling == .openOnHolidayCloseNextWeekday,
           isHolidayFollowupClosedDay(day) {
            return .closed
        }
        
        let weekday = cal.component(.weekday, from: day)
        let closedWeekdays = exhibition.scheduleClosedWeekdays
            .compactMap { Weekday(rawValue: $0.lowercased()) }
        if closedWeekdays.contains(where: { $0.calendarValue == weekday }) {
            return .closed
        }
        
        return .open(openTime: exhibition.scheduleOpenTime ?? "未設定",
                     closeTime: exhibition.scheduleCloseTime ?? "未設定",
                     lastEntryTime: exhibition.scheduleLastEntryTime)
    }
    
    private static func isSameDay(_ lhs: Date, _ rhs: Date) -> Bool {
        let cal = Calendar.japan
        return cal.isDate(lhs, inSameDayAs: rhs)
    }
    
    private static func isBusinessDay(_ date: Date) -> Bool {
        let cal = Calendar.japan
        let weekday = cal.component(.weekday, from: date)
        let isWeekend = weekday == 1 || weekday == 7
        return !isWeekend && !isJapaneseHoliday(date)
    }
    
    // 祝日の翌平日（振替休館）かどうか
    private static func isHolidayFollowupClosedDay(_ date: Date) -> Bool {
        let cal = Calendar.japan
        var cursor = cal.date(byAdding: .day, value: -1, to: date)!
        var foundHoliday = false
        while true {
            if isJapaneseHoliday(cursor) {
                foundHoliday = true
            }
            let weekday = cal.component(.weekday, from: cursor)
            let isWeekend = weekday == 1 || weekday == 7
            if !isWeekend && !isJapaneseHoliday(cursor) {
                break
            }
            guard let prev = cal.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return foundHoliday
    }
    
    private static func holidayHandling(from rawValue: String?) -> HolidayHandling? {
        guard let raw = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
              !raw.isEmpty
        else { return nil }
        switch raw {
        case "NONE": return .none
        case "OPEN_ON_HOLIDAY": return .openOnHoliday
        case "OPEN_ON_HOLIDAY_CLOSE_NEXT_WEEKDAY": return .openOnHolidayCloseNextWeekday
        default: return nil
        }
    }
    
    private static func matchSpecialOpening(
        _ openings: [SpecialOpeningRecord],
        _ day: Date,
        _ cal: Calendar
    ) -> SpecialOpeningRecord? {
        if let exact = openings.first(where: { record in
            guard record.ruleType == .date,
                  let dateString = record.date,
                  let date = parseYMD(dateString)
            else { return false }
            return cal.isDate(date, inSameDayAs: day)
        }) {
            return exact
        }
        if let inRange = openings.first(where: { record in
            guard record.ruleType == .range,
                  let startText = record.startDate,
                  let endText = record.endDate,
                  let startDate = parseYMD(startText),
                  let endDate = parseYMD(endText)
            else { return false }
            let start = cal.startOfDay(for: startDate)
            let end = cal.startOfDay(for: endDate)
            return day >= start && day <= end
        }) {
            return inRange
        }
        let weekday = cal.component(.weekday, from: day)
        return openings.first(where: { record in
            guard record.ruleType == .weekday,
                  let w = record.weekday
            else { return false }
            return w.calendarValue == weekday
        })
    }

    private static func matchesDateRule(
        _ rules: [DateRuleRecord],
        _ day: Date,
        _ cal: Calendar
    ) -> Bool {
        rules.contains { rule in
            switch rule.ruleType {
            case .date:
                guard let dateString = rule.date,
                      let date = parseYMD(dateString)
                else { return false }
                return cal.isDate(date, inSameDayAs: day)
            case .range:
                guard let startText = rule.startDate,
                      let endText = rule.endDate,
                      let start = parseYMD(startText),
                      let end = parseYMD(endText)
                else { return false }
                let startDay = cal.startOfDay(for: start)
                let endDay = cal.startOfDay(for: end)
                return day >= startDay && day <= endDay
            }
        }
    }

    private static func parseYMD(_ text: String) -> Date? {
        let formatter = DateFormatter.japanese()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: text.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
