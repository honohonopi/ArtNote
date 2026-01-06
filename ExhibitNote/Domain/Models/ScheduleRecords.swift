//
//  ScheduleRecords.swift
//  ExhibitNote
//
//  Created by Honoka Nishiyama on 2026/01/06.
//

import Foundation

/// scheduleSpecialOpeningsData に保存する「開館時間が通常と異なるルール」
/// - date: 特定日(YYYY-MM-DD)
/// - weekday: 毎週ルール(EVERY_FRIDAYなど)は Weekday で表現
enum SpecialOpeningRuleType: String, Codable {
    case date
    case weekday
    case range
}

struct SpecialOpeningRecord: Codable, Identifiable, Equatable {
    var id: String = UUID().uuidString

    var ruleType: SpecialOpeningRuleType
    /// ruleType == .date のときのみ使用（YYYY-MM-DD）
    var date: String?
    /// ruleType == .range のときのみ使用（YYYY-MM-DD）
    var startDate: String?
    var endDate: String?
    /// ruleType == .weekday のときのみ使用
    var weekday: Weekday?

    var openTime: String     // "HH:mm"
    var closeTime: String    // "HH:mm"
    var lastEntryTime: String?
    var note: String?

    static func forDate(
        _ date: String,
        openTime: String,
        closeTime: String,
        lastEntryTime: String? = nil,
        note: String? = nil
    ) -> SpecialOpeningRecord {
        .init(ruleType: .date, date: date, startDate: nil, endDate: nil, weekday: nil,
              openTime: openTime, closeTime: closeTime,
              lastEntryTime: lastEntryTime, note: note)
    }

    static func forWeekday(
        _ weekday: Weekday,
        openTime: String,
        closeTime: String,
        lastEntryTime: String? = nil,
        note: String? = nil
    ) -> SpecialOpeningRecord {
        .init(ruleType: .weekday, date: nil, startDate: nil, endDate: nil, weekday: weekday,
              openTime: openTime, closeTime: closeTime,
              lastEntryTime: lastEntryTime, note: note)
    }

    static func forRange(
        start: String,
        end: String,
        openTime: String,
        closeTime: String,
        lastEntryTime: String? = nil,
        note: String? = nil
    ) -> SpecialOpeningRecord {
        .init(ruleType: .range, date: nil, startDate: start, endDate: end, weekday: nil,
              openTime: openTime, closeTime: closeTime,
              lastEntryTime: lastEntryTime, note: note)
    }
}

struct SpecialOpening: Equatable {
    enum Rule: Equatable {
        case date(Date)
        case weekday(Weekday)
        case range(start: Date, end: Date)
    }

    var rule: Rule
    var openTime: String
    var closeTime: String
    var lastEntryTime: String?
    var note: String?
}

private enum ScheduleDateFormat {
    static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

extension SpecialOpeningRecord {
    func toSpecialOpening() -> SpecialOpening? {
        switch ruleType {
        case .date:
            guard let dateString = date,
                  let dateValue = ScheduleDateFormat.formatter.date(from: dateString) else {
                return nil
            }
            return SpecialOpening(rule: .date(dateValue),
                                  openTime: openTime,
                                  closeTime: closeTime,
                                  lastEntryTime: lastEntryTime,
                                  note: note)
        case .weekday:
            guard let weekday = weekday else { return nil }
            return SpecialOpening(rule: .weekday(weekday),
                                  openTime: openTime,
                                  closeTime: closeTime,
                                  lastEntryTime: lastEntryTime,
                                  note: note)
        case .range:
            guard let start = startDate,
                  let end = endDate,
                  let startDate = ScheduleDateFormat.formatter.date(from: start),
                  let endDate = ScheduleDateFormat.formatter.date(from: end)
            else { return nil }
            return SpecialOpening(rule: .range(start: startDate, end: endDate),
                                  openTime: openTime,
                                  closeTime: closeTime,
                                  lastEntryTime: lastEntryTime,
                                  note: note)
        }
    }
}

extension SpecialOpening {
    func toRecord() -> SpecialOpeningRecord {
        switch rule {
        case .date(let dateValue):
            let text = ScheduleDateFormat.formatter.string(from: dateValue)
            return .forDate(text,
                            openTime: openTime,
                            closeTime: closeTime,
                            lastEntryTime: lastEntryTime,
                            note: note)
        case .weekday(let weekday):
            return .forWeekday(weekday,
                               openTime: openTime,
                               closeTime: closeTime,
                               lastEntryTime: lastEntryTime,
                               note: note)
        case .range(let start, let end):
            let startText = ScheduleDateFormat.formatter.string(from: start)
            let endText = ScheduleDateFormat.formatter.string(from: end)
            return .forRange(start: startText,
                             end: endText,
                             openTime: openTime,
                             closeTime: closeTime,
                             lastEntryTime: lastEntryTime,
                             note: note)
        }
    }
}
