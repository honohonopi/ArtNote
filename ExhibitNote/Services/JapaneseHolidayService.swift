//
//  JapaneseHolidayService.swift
//  ExhibitNote
//
//  Created by Codex on 2026/01/xx.
//

import Foundation

enum JapaneseHolidayService {
    static let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "ja_JP")
        cal.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current
        return cal
    }()

    static func isHoliday(_ date: Date) -> Bool {
        let day = calendar.startOfDay(for: date)
        let year = calendar.component(.year, from: day)
        let holidays = holidaySet(for: year)
        return holidays.contains(day)
    }

    private static func holidaySet(for year: Int) -> Set<Date> {
        var set: Set<Date> = []

        func add(_ month: Int, _ day: Int) {
            if let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) {
                set.insert(calendar.startOfDay(for: date))
            }
        }

        // Fixed holidays
        add(1, 1)   // New Year's Day
        add(2, 11)  // National Foundation Day
        add(4, 29)  // Showa Day
        add(5, 3)   // Constitution Memorial Day
        add(5, 4)   // Greenery Day
        add(5, 5)   // Children's Day
        add(8, 11)  // Mountain Day
        add(11, 3)  // Culture Day
        add(11, 23) // Labor Thanksgiving Day

        // Emperor's Birthday (current rule)
        if year >= 2020 {
            add(2, 23)
        }

        // Happy Monday system
        if let comingOfAge = nthWeekday(of: .monday, ordinal: 2, month: 1, year: year) {
            set.insert(comingOfAge)
        }
        if let marineDay = nthWeekday(of: .monday, ordinal: 3, month: 7, year: year) {
            set.insert(marineDay)
        }
        if let respectForAged = nthWeekday(of: .monday, ordinal: 3, month: 9, year: year) {
            set.insert(respectForAged)
        }
        if let sportsDay = nthWeekday(of: .monday, ordinal: 2, month: 10, year: year) {
            set.insert(sportsDay)
        }

        // Equinoxes
        if let vernal = equinoxDate(year: year, type: .vernal) {
            set.insert(vernal)
        }
        if let autumnal = equinoxDate(year: year, type: .autumnal) {
            set.insert(autumnal)
        }

        // Substitute holidays (if holiday falls on Sunday)
        let sundayHolidays = set.filter { calendar.component(.weekday, from: $0) == 1 }
        for holiday in sundayHolidays {
            var next = calendar.date(byAdding: .day, value: 1, to: holiday)!
            while set.contains(calendar.startOfDay(for: next)) {
                next = calendar.date(byAdding: .day, value: 1, to: next)!
            }
            set.insert(calendar.startOfDay(for: next))
        }

        // Citizens' holidays: a day between two holidays becomes a holiday
        var cursor = calendar.date(from: DateComponents(year: year, month: 1, day: 2))!
        let end = calendar.date(from: DateComponents(year: year, month: 12, day: 30))!
        while cursor <= end {
            let prev = calendar.date(byAdding: .day, value: -1, to: cursor)!
            let next = calendar.date(byAdding: .day, value: 1, to: cursor)!
            if !set.contains(cursor) && set.contains(prev) && set.contains(next) {
                set.insert(cursor)
            }
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor)!
        }

        return set
    }

    private static func nthWeekday(of weekday: Weekday, ordinal: Int, month: Int, year: Int) -> Date? {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.weekday = weekday.rawValue
        comps.weekdayOrdinal = ordinal
        return calendar.date(from: comps).map { calendar.startOfDay(for: $0) }
    }

    private enum EquinoxType { case vernal, autumnal }

    private static func equinoxDate(year: Int, type: EquinoxType) -> Date? {
        // Approximation for 1980-2099
        let y = Double(year - 1980)
        let base: Double
        switch type {
        case .vernal:
            base = 20.8431
        case .autumnal:
            base = 23.2488
        }
        let day = Int(floor(base + 0.242194 * y - floor(y / 4.0)))
        let month = (type == .vernal) ? 3 : 9
        return calendar.date(from: DateComponents(year: year, month: month, day: day))
            .map { calendar.startOfDay(for: $0) }
    }

    private enum Weekday: Int {
        case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday
    }
}
