//
//  YearMonth.swift
//  ExhibitNote
//
//  Created by Honoka Nishiyama on 2025/11/08.
//

import Foundation

struct YearMonth: Equatable, Hashable {
    let year: Int
    let month: Int  // 1...12
    
    init(year: Int, month: Int) {
        self.year = year
        self.month = month
    }

    /// 今日の YearMonth
    static var today: YearMonth {
        let now = Date()
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: now)
        return YearMonth(year: comps.year!, month: comps.month!)
    }

    /// Date をこの月の1日に変換
    func firstDay() -> Date? {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: 1))
    }

    /// 次の月
    func nextMonth() -> YearMonth {
        var y = year
        var m = month + 1
        if m > 12 { m = 1; y += 1 }
        return YearMonth(year: y, month: m)
    }

    /// 前の月
    func previousMonth() -> YearMonth {
        var y = year
        var m = month - 1
        if m < 1 { m = 12; y -= 1 }
        return YearMonth(year: y, month: m)
    }
}
