//
//  CalendarSpan.swift
//  ArtNote
//
//  Created by Honoka Nishiyama on 2025/10/18.
//

// カレンダー上の期間データ
import Foundation

/// 週内に横断して表示する帯の区間（UIとは独立した純データ）
struct EventSpan {
    let startColumn: Int  // 0...6
    let endColumn: Int    // 0...6
    let row: Int          // バンドの縦段（重なり解消で増える）
    let title: String
}

/// 会期を週ごとに分割したサブ区間
struct WeekSpan {
    let weekStart: Date
    let start: Date
    let end: Date
}
