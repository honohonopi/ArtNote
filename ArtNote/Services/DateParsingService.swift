//
//  DateParsingService.swift
//  ArtNote
//
//  Created by Honoka Nishiyama on 2025/10/03.
//

import Foundation

struct DateParsingService {

    /// テキストから日付の最小/最大を拾って (start, end) を返す
    /// 例: 「2025/10/1(水)〜12/3(日)」, 「Oct 1, 2025 - Dec 3, 2025」
    static func extractDateRange(from text: String, locale: Locale = .current, tz: TimeZone = .current) -> (start: Date, end: Date)? {
        // 改行や余白を正規化
        let normalized = text.replacingOccurrences(of: "年", with: "/")
            .replacingOccurrences(of: "月", with: "/")
            .replacingOccurrences(of: "日", with: "")
            .replacingOccurrences(of: "〜", with: "-")
            .replacingOccurrences(of: "～", with: "-")

        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else { return nil }

        var dates: [Date] = []
        var ranges: [(Date, Date)] = []

        let whole = NSRange(location: 0, length: (normalized as NSString).length)
        detector.enumerateMatches(in: normalized, options: [], range: whole) { match, _, _ in
            guard let m = match, m.resultType == .date, let d = m.date else { return }
            // duration（秒）が入っている場合は範囲として扱う
            if m.duration > 0 {
                let end = d.addingTimeInterval(m.duration)
                ranges.append((d, end))
            } else {
                dates.append(d)
            }
        }

        // 範囲が1つでも取れていたら、それを優先
        if let r = ranges.sorted(by: { $0.0 < $1.0 }).first {
            return (start: r.0, end: r.1)
        }

        // 単一日付が複数ある場合は、最小=開始、最大=終了で採用
        if let minD = dates.min(), let maxD = dates.max() {
            // 同日しか拾えない場合は start=end とする
            return (start: minD, end: maxD)
        } else if let only = dates.first {
            // 1個しか拾えない→開始=終了（後でユーザーが修正）
            return (start: only, end: only)
        }

        return nil
    }
}
