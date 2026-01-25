//
//  TitleExtractor.swift
//  ArtNote
//
//  Created by Honoka Nishiyama on 2025/10/03.
//

// 展覧会タイトル推定
import Foundation

struct TitleExtractor {
    struct LineInfo {
        let text: String
        let index: Int
        let height: Double
    }

    /// 展覧会名の候補（スコア降順）を返す
    static func candidates(from text: String) -> [String] {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let infos = lines.enumerated().map { LineInfo(text: $0.element, index: $0.offset, height: 0) }
        return candidates(from: infos)
    }

    static func candidates(from items: [RecognizedTextItem], fallbackText: String) -> [String] {
        let infos = items.enumerated().map {
            LineInfo(text: $0.element.text, index: $0.offset, height: Double($0.element.boundingBoxHeight))
        }
        let filtered = infos.filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if filtered.isEmpty {
            return candidates(from: fallbackText)
        }
        return candidates(from: filtered)
    }

    private static func candidates(from lines: [LineInfo]) -> [String] {
        // よくあるキーワード
        let titleHintsJP = ["展覧会","特別展","企画展","美術展","回顧展","コレクション展","◯◯展"]
        let titleHintsEN = ["Exhibition","Special Exhibition","Retrospective","Collection","Show"]
        // 除外語（主催者情報・観覧料など）
        let excludeWords = ["主催","共催","後援","協力","開館","開室","観覧料","料金",
                            "休館","Open","Closed","Admission","Ticket","Access"]

        var scored: [(str: String, score: Int)] = []
        let maxHeight = lines.map(\.height).max() ?? 0

        for info in lines {
            let idx = info.index
            var s = info.text
            s = s.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            let sFlat = s.replacingOccurrences(of: " ", with: "")

            // ノイズ除去：URL/日時/価格/電話
            if hasNoise(s) { continue }
            // 除外ワード
            if excludeWords.contains(where: { s.localizedCaseInsensitiveContains($0) }) { continue }

            var score = 0
            let sizeBonus: Int = {
                guard maxHeight > 0 else { return 0 }
                let ratio = min(max(info.height / maxHeight, 0), 1)
                return Int((ratio * 6).rounded())
            }()
            // 日本語の「◯◯展」
            if let m = regexMatch(sFlat, pattern: "(.{2,40}?展)($|[^\\u3040-\\u30FF\\u4E00-\\u9FFF])") {
                let cand = postTrim(m)
                score += 6 + min(cand.count / 4, 6) + sizeBonus
                scored.append((cand, score + headlineBonus(idx)))
                continue
            }
            // 引用符つきタイトル
            if let m = regexMatch(s, pattern: "[\\\"\\“\\”\\‘\\’\\'\\「\\『](.+?)[\\\"\\“\\”\\‘\\’\\'\\」\\』]") {
                let cand = postTrim(m)
                if looksLikeTitle(cand) {
                    score += 5 + min(cand.count / 5, 5) + sizeBonus
                    scored.append((cand, score + headlineBonus(idx)))
                    continue
                }
            }
            // 英語タイトル + Exhibition
            if let m = regexMatch(s, pattern: "(.{2,60}?(Exhibition|Retrospective|Show))") {
                let cand = postTrim(m)
                score += 5 + min(cand.count / 5, 5) + sizeBonus
                scored.append((cand, score + headlineBonus(idx)))
                continue
            }
            // ヒント語を含む行
            if titleHintsJP.contains(where: { s.contains($0) }) ||
                titleHintsEN.contains(where: { s.localizedCaseInsensitiveContains($0) }) {
                let cand = postTrim(s)
                score += 3 + min(cand.count / 6, 4) + sizeBonus
                scored.append((cand, score + headlineBonus(idx)))
                continue
            }

            if sizeBonus >= 4, looksLikeTitleCandidate(s) {
                let cand = postTrim(s)
                score += 2 + sizeBonus
                scored.append((cand, score + headlineBonus(idx)))
            }
        }

        // 重複統合 → 降順
        let unique = Dictionary(grouping: scored, by: { $0.str })
            .map { ($0.key, $0.value.map { $0.score }.max() ?? 0) }
            .sorted { $0.1 > $1.1 }
            .map { $0.0 }

        // 長さフィルタ
        return unique.filter { $0.count >= 2 && $0.count <= 40 }
    }

    static func best(from text: String) -> String? { candidates(from: text).first }

    // MARK: - Helpers
    private static func hasNoise(_ s: String) -> Bool {
        let patterns = [
            "https?://[A-Za-z0-9./_-]+",            // URL
            "[0-9]{1,2}:[0-9]{2}",                   // 時刻
            "[0-9]{4}/[0-9]{1,2}/[0-9]{1,2}",       // yyyy/MM/dd
            "[0-9]{1,2}/[0-9]{1,2}/[0-9]{2,4}",     // M/d/yy
            "[0-9]+円",                               // 料金
            "TEL[:：]?\\s*[0-9-]+",                 // 電話
        ]
        for p in patterns {
            if (try? NSRegularExpression(pattern: p))?
                .firstMatch(in: s, options: [], range: NSRange(location: 0, length: (s as NSString).length)) != nil {
                return true
            }
        }
        return false
    }

    private static func headlineBonus(_ index: Int) -> Int {
        // 上の方の行ほどボーナス
        return max(0, 6 - min(index, 6))
    }

    private static func regexMatch(_ s: String, pattern: String) -> String? {
        guard let r = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns = s as NSString
        let range = NSRange(location: 0, length: ns.length)
        guard let m = r.firstMatch(in: s, options: [], range: range) else { return nil }
        if m.numberOfRanges >= 2 { return ns.substring(with: m.range(at: 1)) }
        return ns.substring(with: m.range)
    }

    private static func postTrim(_ s: String) -> String {
        var t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        t = t.replacingOccurrences(of: "（.+?）", with: "", options: .regularExpression)
        t = t.trimmingCharacters(in: CharacterSet(charactersIn: " 　・:：—-、。/|"))
        return t
    }

    private static func looksLikeTitle(_ s: String) -> Bool {
        let genericWords = ["開催","お知らせ","Information","Notice","News"]
        return !genericWords.contains(where: { s.localizedCaseInsensitiveContains($0) })
    }

    private static func looksLikeTitleCandidate(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.count < 2 || t.count > 40 { return false }
        if hasNoise(t) { return false }
        if !looksLikeTitle(t) { return false }
        return true
    }
}
