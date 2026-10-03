//
//  ScheduleTypes.swift
//  ArtNote
//
//  Created by Honoka Nishiyama on 2026/01/05.
//

import Foundation

enum Weekday: String, CaseIterable, Codable {
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

// 祝日対応
enum HolidayHandling: String, CaseIterable, Codable {
    case none = "NONE"
    case openOnHoliday = "OPEN_ON_HOLIDAY"
    case openOnHolidayCloseNextWeekday = "OPEN_ON_HOLIDAY_CLOSE_NEXT_WEEKDAY"
}
