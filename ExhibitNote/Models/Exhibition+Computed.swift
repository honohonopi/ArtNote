//
//  Exhibition+Computed.swift
//  ExhibitNote
//
//  Created by Honoka Nishiyama on 2026/01/06.
//

import Foundation
import SwiftUI

extension Exhibition {
    // ステータス（未開催/開催中/終了）
    enum RunStatus: String, CaseIterable, Identifiable {
        case notStarted, ongoing, finished
        var id: Self { self }
        var label: String {
            switch self {
            case .notStarted: return "未開催"
            case .ongoing:    return "開催中"
            case .finished:   return "終了"
            }
        }

        var badgeText: String { label }

        var badgeColor: Color {
            switch self {
            case .notStarted: return .orange
            case .ongoing: return .green
            case .finished: return .gray
            }
        }
    }
    
    var runStatus: RunStatus {
        let today = Calendar.japan.startOfDay(for: Date())
        let sd = Calendar.japan.startOfDay(for: startDate)
        let ed = Calendar.japan.startOfDay(for: endDate)

        if today < sd { return .notStarted }
        if today > ed { return .finished }
        return .ongoing
    }

    // typed accessors（保存はStringのままでも扱いは安全に）
    var closedWeekdaysEnum: [Weekday] {
        get { scheduleClosedWeekdays.compactMap(Weekday.init(rawValue:)) }
        set { scheduleClosedWeekdays = newValue.map(\.rawValue) }
    }

    var holidayHandlingEnum: HolidayHandling {
        get { HolidayHandling(rawValue: scheduleHolidayHandling ?? "NONE") ?? .none }
        set { scheduleHolidayHandling = newValue.rawValue }
    }
}
