//
//  Date+Format.swift
//  ArtNote
//
//  Created by Honoka Nishiyama on 2025/10/19.
//

import Foundation

extension Date {
    /// 表示用の日付文字列（例: 2025/11/25）
    var ymdString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: self)
    }
}
