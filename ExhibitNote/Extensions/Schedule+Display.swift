extension Weekday {
    var displayName: String {
        switch self {
        case .monday: return "月曜日"
        case .tuesday: return "火曜日"
        case .wednesday: return "水曜日"
        case .thursday: return "木曜日"
        case .friday: return "金曜日"
        case .saturday: return "土曜日"
        case .sunday: return "日曜日"
        }
    }

    var shortDisplayName: String {
        String(displayName.prefix(1))
    }
}

extension HolidayHandling {
    var displayName: String {
        switch self {
        case .none: return "祝日対応なし"
        case .openOnHoliday: return "祝日は開館"
        case .openOnHolidayCloseNextWeekday: return "祝日開館・翌平日休館"
        }
    }
}

extension SpecialOpening {
    var displayLabel: String {
        switch rule {
        case .date(let date):
            return date.ymdString
        case .weekday(let weekday):
            return weekday.displayName
        case .range(let start, let end):
            return "\(start.ymdString)〜\(end.ymdString)"
        }
    }
}
