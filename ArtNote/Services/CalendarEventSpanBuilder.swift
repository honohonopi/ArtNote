//
//  CalendarEventSpanBuilder.swift
//  ArtNote
//
//  Created by Honoka Nishiyama on 2025/10/19.
//

import Foundation

struct CalendarEventSpanBuilder {
    
    static func buildDaysMatrix(for monthAnchor: Date, cal: Calendar) -> [[Date?]] {
        let startOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: monthAnchor))!
        let daysInMonth = cal.range(of: .day, in: .month, for: startOfMonth)!.count
        let firstWeekdayIndex = (cal.component(.weekday, from: startOfMonth) - cal.firstWeekday + 7) % 7
        
        var matrix: [[Date?]] = []
        var row: [Date?] = Array(repeating: nil, count: 7)
        var day = 1
        // 1行目：前月の空白 + 当月
        for col in 0..<7 {
            if col >= firstWeekdayIndex {
                row[col] = cal.date(byAdding: .day, value: day - 1, to: startOfMonth)
                day += 1
            }
        }
        matrix.append(row)
        
        // 残り
        while day <= daysInMonth {
            var r: [Date?] = Array(repeating: nil, count: 7)
            for col in 0..<7 where day <= daysInMonth {
                r[col] = cal.date(byAdding: .day, value: day - 1, to: startOfMonth)
                day += 1
            }
            matrix.append(r)
        }
        // 6週に満たなければ空行で埋める
        while matrix.count < 6 { matrix.append(Array(repeating: nil, count: 7)) }
        return matrix
    }
    
    static func weekdayColumn(for date: Date, cal: Calendar) -> Int {
        (cal.component(.weekday, from: date) - cal.firstWeekday + 7) % 7
    }
    
    static func splitByWeek(start: Date, end: Date, cal: Calendar) -> [WeekSpan] {
        var out: [WeekSpan] = []
        var s = cal.startOfDay(for: start)
        let e = cal.startOfDay(for: end)
        while s <= e {
            let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: s))!
            let weekEnd = cal.date(byAdding: .day, value: 6, to: weekStart)!
            let subEnd = min(weekEnd, e)
            out.append(.init(weekStart: weekStart, start: s, end: subEnd))
            guard let next = cal.date(byAdding: .day, value: 1, to: subEnd) else { break }
            s = next
        }
        return out
    }
    
}
