//
//  CalendarViewModel.swift
//  ArtNote
//
//  Created by Honoka Nishiyama on 2025/10/18.
//

import Foundation

@MainActor
final class CalendarViewModel: ObservableObject {
    @Published var selectedDate: Date? = nil
    @Published var showDaySheet: Bool = false
    @Published var selectedExhibitionForFullScreen: Exhibition? = nil

    func exhibitions(on date: Date, from all: [Exhibition]) -> [Exhibition] {
        let cal = Calendar.current
        let d = cal.startOfDay(for: date)
        return all.filter { ex in
            cal.startOfDay(for: ex.startDate) <= d && d <= cal.startOfDay(for: ex.endDate)
        }
    }
}
