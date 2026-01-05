//
//  ScheduleTypes.swift
//  ArtNote
//
//  Created by Honoka Nishiyama on 2026/01/05.
//

import Foundation

// スケジュール判定と保存で使う共通型
struct SpecialOpening {
    enum Rule {
        case date(Date)
        case weekday(Weekday)
    }
    
    var rule: Rule
    var openTime: String
    var closeTime: String
    var lastEntryTime: String?
    var note: String?
}

enum HolidayHandling {
    case none
    case openOnHoliday
    case openOnHolidayCloseNextWeekday
}

enum Weekday: String, CaseIterable {
    case sunday, monday, tuesday, wednesday, thursday, friday, saturday
    
    var calendarValue: Int {
        switch self {
        case .sunday: return 1
        case .monday: return 2
        case .tuesday: return 3
        case .wednesday: return 4
        case .thursday: return 5
        case .friday: return 6
        case .saturday: return 7
        }
    }
}
