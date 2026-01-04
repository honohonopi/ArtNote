//
//  DateParsingService.swift
//  ArtNote
//
//  Created by Honoka Nishiyama on 2025/10/03.
//

// 日付抽出
import Foundation

struct DateParsingService {

    // 最良1件
    static func extractDateRange(from text: String) -> (start: Date, end: Date)? {
        candidates(from: text).first
    }

    // 全候補（開始日の早い順）
    static func candidates(from raw: String) -> [(start: Date, end: Date)] {
        let normalized = normalize(raw)
        var pairs: [(Date, Date)] = []

        // 1) 行単位で拾う（ただし本文全体も1本として見る）
        let lines = normalized.components(separatedBy: .newlines)
        for line in lines {
            if let p = pairWithYear(in: line) { pairs.append(p) }
            if let p = pairMonthDay(in: line) { pairs.append(p) }
            if let p = pairMonthDayEndOnly(in: line) { pairs.append(p) } // 4/12〜19
        }
        // 全体でもう一度（行を跨ぐパターン対策）
        if pairs.isEmpty {
            if let p = pairWithYear(in: normalized) { pairs.append(p) }
            if let p = pairMonthDay(in: normalized) { pairs.append(p) }
            if let p = pairMonthDayEndOnly(in: normalized) { pairs.append(p) }
        }

        // 2) まだ空なら Detector フォールバック（時間だけ除外）
        if pairs.isEmpty, let fallback = pairByDetector(in: normalized) {
            pairs = fallback
        }

        // 3) 重複除去（1日粒度）
        var seen = Set<String>()
        let uniq = pairs.compactMap { s, e -> (Date, Date)? in
            let a = min(s, e), b = max(s, e)
            let key = "\(Int(a.timeIntervalSince1970/86400))-\(Int(b.timeIntervalSince1970/86400))"
            guard !seen.contains(key) else { return nil }
            seen.insert(key)
            return (a, b)
        }

        return uniq.sorted { $0.0 < $1.0 }
    }

    // MARK: - 正規化

    private static let sepRegex = try! NSRegularExpression(pattern: #"\s*[-—–~〜～»]{1,2}\s*"#)

    private static func normalize(_ s: String) -> String {
        var t = s
            // --- 既存処理 ---
            .replacingOccurrences(of: "（", with: "(")
            .replacingOccurrences(of: "）", with: ")")
            .replacingOccurrences(of: "［", with: "[")
            .replacingOccurrences(of: "］", with: "]")
            .replacingOccurrences(of: "・", with: "/")     // ← 中点をスラッシュ扱い
            .replacingOccurrences(of: "年", with: "/")
            .replacingOccurrences(of: "月", with: "/")
            .replacingOccurrences(of: "日", with: "")
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")
            .replacingOccurrences(of: "〜", with: "-")
            .replacingOccurrences(of: "～", with: "-")
            .replacingOccurrences(of: "»", with: "-")
            // 曜日・中括弧削除
            .replacingOccurrences(of: #"\[[^\]]*\]"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\([^) ]*曜\)"#, with: "", options: .regularExpression)

        // --- 追加改良①：圧縮 YYYYMM.DD / YYYYM.DD / YYYYMM.D / YYYYM.D → YYYY.MM.DD 形式へ展開 ---
        // 例: 202511.22 → 2025.11.22
        //     20251.22  → 2025.1.22
        //     202511.3  → 2025.11.3
        //     20251.3   → 2025.1.3
        let compressedFlexible = try! NSRegularExpression(
            pattern: #"(\d{4})(\d{1,2})\.(\d{1,2})"#
        )
        t = compressedFlexible.stringByReplacingMatches(
            in: t,
            range: NSRange(t.startIndex..., in: t),
            withTemplate: "$1.$2.$3"
        )

        // --- 追加改良②：誤認識 SAT → 5AT 補正 ---
        t = t.replacingOccurrences(of: "5AT", with: "SAT")
             .replacingOccurrences(of: "5at", with: "SAT")
             .replacingOccurrences(of: "5At", with: "SAT")

        // --- 追加改良③：変な矢印系は “-” へ統一 ---
        t = t.replacingOccurrences(of: "→", with: "-")
             .replacingOccurrences(of: "＞", with: "-")
             .replacingOccurrences(of: ">", with: "-")

        // --- 追加改良④：曜日 + 余分記号 を削除（WED. → WED） ---
        let dayTail = try! NSRegularExpression(pattern: #"(MON|TUE|WED|THU|FRI|SAT|SUN)[\.\> ]+"#, options: .caseInsensitive)
        t = dayTail.stringByReplacingMatches(
            in: t,
            range: NSRange(t.startIndex..., in: t),
            withTemplate: "$1"
        )

        return t
    }

    // MARK: - パターン

    // yyyy付き（yyyy[/.- ]M[/.-]d 〜 yyyy[/.- ]M[/.-]d）
    private static func pairWithYear(in line: String) -> (Date, Date)? {
        // 年と月日の間にスペースも許容
        let ymd = #"(\d{4})\s*[\/\.-](\d{1,2})[\/\.-](\d{1,2})"#
        if let m = firstMatch(in: line, pattern: ymd + #".{0,12}?"# + sepRegexPattern() + #".{0,12}?"# + ymd),
           m.count == 7 {
            if let a = makeDate(y:m[1], mo:m[2], d:m[3]),
               let b = makeDate(y:m[4], mo:m[5], d:m[6]) {
                return ordered(a, b)
            }
        }
        // 片側だけ年あり → もう片側は同年推定
        let md = #"(\d{1,2})[\/\.-](\d{1,2})"#
        if let m = firstMatch(in: line, pattern: ymd + #".{0,12}?"# + sepRegexPattern() + #".{0,12}?"# + md),
           m.count == 6 {
            let year = m[1]
            if let a = makeDate(y: year, mo: m[2], d: m[3]),
               let b = makeDateInferringYear(baseYear: Int(year)!, mo: m[4], d: m[5], fromStart: a) {
                return ordered(a, b)
            }
        }
        return nil
    }

    // 年なし（M/d 〜 M/d）
    private static func pairMonthDay(in line: String) -> (Date, Date)? {
        let pattern = #"(\d{1,2})[\/\.-](\d{1,2}).{0,10}?"# + sepRegexPattern() + #".{0,10}?(\d{1,2})[\/\.-](\d{1,2})"#
        if let m = firstMatch(in: line, pattern: pattern), m.count == 5 {
            let year = Calendar.current.component(.year, from: Date())
            guard let a = makeDate(y: String(year), mo: m[1], d: m[2]) else { return nil }
            if var b = makeDate(y: String(year), mo: m[3], d: m[4]) {
                if b < a, let nb = Calendar.current.date(byAdding: .year, value: 1, to: b) { b = nb }
                return ordered(a, b)
            }
        }
        return nil
    }

    // 年なし（M/d 〜 d）…終了の月が省略されるパターン「4/12〜19」
    private static func pairMonthDayEndOnly(in line: String) -> (Date, Date)? {
        let pattern = #"(\d{1,2})[\/\.-](\d{1,2}).{0,8}?"# + sepRegexPattern() + #".{0,8}?(\d{1,2})(?![\/\.-])"#
        if let m = firstMatch(in: line, pattern: pattern), m.count == 4 {
            let year = Calendar.current.component(.year, from: Date())
            guard let a = makeDate(y: String(year), mo: m[1], d: m[2]) else { return nil }
            // 終了は開始と同じ月で試し、前後関係で年またぎ補正
            if var b = makeDate(y: String(year), mo: m[1], d: m[3]) {
                if b < a, let nb = Calendar.current.date(byAdding: .year, value: 1, to: b) { b = nb }
                return ordered(a, b)
            }
        }
        return nil
    }

    // フォールバック：Detector（時間だけは捨てる）
    private static func pairByDetector(in text: String) -> [(Date, Date)]? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else { return nil }
        let ns = text as NSString
        let whole = NSRange(location: 0, length: ns.length)
        var items: [(date: Date, range: NSRange)] = []
        detector.enumerateMatches(in: text, options: [], range: whole) { m, _, _ in
            guard let m, m.resultType == .date, let d = m.date else { return }
            let frag = ns.substring(with: m.range)
            if frag.contains(":") && m.range.length <= 8 { return } // 時刻のみ
            items.append((d, m.range))
        }
        if items.isEmpty { return nil }

        var result: [(Date, Date)] = []
        for i in 0..<(items.count - 1) {
            let a = items[i], b = items[i+1]
            let between = NSRange(location: a.range.upperBound, length: b.range.location - a.range.upperBound)
            if let m = sepRegex.firstMatch(in: text, options: [], range: between), m.range.length > 0 {
                if abs(a.date.timeIntervalSince(b.date)) < 366*86400 {
                    result.append(ordered(a.date, b.date))
                }
            }
        }
        if result.isEmpty, let minD = items.map({ $0.date }).min(), let maxD = items.map({ $0.date }).max() {
            result.append(ordered(minD, maxD))
        }
        return result
    }

    // MARK: - Helpers

    private static func sepRegexPattern() -> String { #"\s*[-—–~〜～»]{1,2}\s*"# }

    private static func makeDate(y: String, mo: String, d: String) -> Date? {
        var c = DateComponents()
        c.calendar = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone.current
        c.year = Int(y); c.month = Int(mo); c.day = Int(d)
        return c.date
    }

    private static func makeDateInferringYear(baseYear: Int, mo: String, d: String, fromStart start: Date) -> Date? {
        var c = DateComponents()
        c.calendar = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone.current
        c.year = baseYear; c.month = Int(mo); c.day = Int(d)
        guard var date = c.date else { return nil }
        if date < start, let nb = Calendar.current.date(byAdding: .year, value: 1, to: date) { date = nb }
        return date
    }

    private static func firstMatch(in s: String, pattern: String) -> [String]? {
        guard let r = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns = s as NSString
        let range = NSRange(location: 0, length: ns.length)
        guard let m = r.firstMatch(in: s, options: [], range: range) else { return nil }
        var groups: [String] = []
        for i in 0..<m.numberOfRanges { groups.append(ns.substring(with: m.range(at: i))) }
        return groups
    }

    private static func ordered(_ a: Date, _ b: Date) -> (Date, Date) {
        (min(a, b), max(a, b))
    }
    
    /// 文字列が「明らかに期間っぽい見た目」かどうかだけ判定する
    static func looksLikePeriodText(_ text: String) -> Bool {
        let t = text.replacingOccurrences(of: " ", with: "")

        // ① 圧縮 YYYYMM.DD っぽいものを含んでいるか
        let condensedPattern = #"\d{4}\d{1,2}\.\d{1,2}"#   // 202511.22 など
        if t.range(of: condensedPattern, options: .regularExpression) != nil {
            return true
        }

        // ② MM.DD〜MM.DD / MM.DD→MM.DD / MM.DD-MM.DD っぽいもの
        let rangePattern = #"\d{1,2}\.\d{1,2}\s*[→\-〜~ー–—]\s*\d{1,2}\.\d{1,2}"#
        if t.range(of: rangePattern, options: .regularExpression) != nil {
            return true
        }

        return false
    }
}
