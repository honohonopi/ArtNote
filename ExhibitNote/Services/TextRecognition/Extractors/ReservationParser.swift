//
//  ReservationParser.swift
//  ExhibitNote
//
//  Created by Codex on 2026/01/xx.
//

import Foundation

enum ReservationParser {
    static func parse(from text: String) -> Bool? {
        let normalized = text.replacingOccurrences(of: " ", with: "")
        if normalized.contains("予約不要") ||
            normalized.contains("予約なし") ||
            normalized.contains("予約不要です") ||
            normalized.contains("当日券あり") ||
            normalized.contains("予約不要・当日可") {
            return false
        }
        if normalized.contains("事前予約") ||
            normalized.contains("要予約") ||
            normalized.contains("予約制") ||
            normalized.contains("事前申込") ||
            normalized.contains("要事前") {
            return true
        }
        return nil
    }
}
