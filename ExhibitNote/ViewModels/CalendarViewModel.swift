//
//  CalendarViewModel.swift
//  ArtNote
//
//  Created by Honoka Nishiyama on 2025/10/18.
//

import Foundation
import Observation

@MainActor
@Observable
final class CalendarViewModel {
    var selectedDate: Date? = nil
    var showDaySheet: Bool = false

    func exhibitions(on date: Date, from all: [Exhibition]) -> [Exhibition] {
        let cal = Calendar.japan
        let d = cal.startOfDay(for: date)
        return all.filter { ex in
            cal.startOfDay(for: ex.startDate) <= d && d <= cal.startOfDay(for: ex.endDate)
        }
    }
}
