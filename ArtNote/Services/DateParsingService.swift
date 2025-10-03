//
//  DateParsingService.swift
//  ArtNote
//
//  Created by Honoka Nishiyama on 2025/10/03.
//

import Foundation

/// ポスター画像のLive Textで抽出した文字列から、日付レンジっぽいものを拾う簡易パーサ
struct DateParsingService {
    static func extractDateRange(from text: String) -> (start: Date, end: Date)? {
        // 簡易実装：NSDataDetectorを使うのが本番。ここはダミー。
        // 実装のヒント：DateDetectorで全マッチをとり、最小・最大を採用する。
        return nil
    }
}
