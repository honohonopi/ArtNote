//
//  VenueExtractionService.swift
//  ArtNote
//
//  Created by Honoka Nishiyama on 2025/10/03.
//

// 会場名推定
import Foundation

struct VenueExtractionService {
    static func candidates(from text: String) -> [String] {
        let keywordsJP = ["美術館","博物館","ミュージアム","ギャラリー","資料館","記念館"]
        let keywordsEN = ["Museum","Art Museum","Gallery","Memorial","Center"]
        let hintWords  = ["会場","会　場","開催場所","会場：","会場:","会場/","会場 "]

        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var scored: [(str: String, score: Int)] = []

        for line in lines {
            let clean = normalize(line)
            var score = 0
            if hintWords.contains(where: { clean.replacingOccurrences(of: " ", with: "").contains($0.replacingOccurrences(of: " ", with: "")) }) { score += 3 }
            if keywordsJP.contains(where: { clean.localizedCaseInsensitiveContains($0) }) { score += 2 }
            if keywordsEN.contains(where: { clean.localizedCaseInsensitiveContains($0) }) { score += 2 }

            // ◯◯美術館 / ◯◯ギャラリー / など
            if let m = regexMatch(clean, pattern: "(.{0,30}?(美術館|博物館|ミュージアム|ギャラリー|資料館|記念館))") {
                let cand = postProcess(m)
                scored.append((cand, score + min(cand.count / 4, 4)))
                continue
            }
            // 「会場: 〜」パターン（\s は \\s でエスケープ）
            if let m = regexMatch(clean, pattern: "(?:会場[:：\\s]+)(.+)") {
                let cand = postProcess(m)
                scored.append((cand, score + 2 + min(cand.count / 5, 3)))
                continue
            }
        }

        let unique = Dictionary(grouping: scored, by: { $0.str })
            .map { ($0.key, $0.value.map { $0.score }.max() ?? 0) }
            .sorted { $0.1 > $1.1 }
            .map { $0.0 }

        return unique.filter { $0.count >= 2 && $0.count <= 40 }
    }

    static func best(from text: String) -> String? { candidates(from: text).first }

    private static func normalize(_ s: String) -> String {
        var s = s
        s = s.replacingOccurrences(of: "https?://[A-Za-z0-9./_-]+", with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: "[0-9]{2}:[0-9]{2}", with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: "TEL[:：]?\\s*[0-9-]+", with: "", options: .regularExpression) // ← \\s*
        return s
    }

    private static func regexMatch(_ s: String, pattern: String) -> String? {
        guard let r = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns = s as NSString
        let range = NSRange(location: 0, length: ns.length)
        guard let m = r.firstMatch(in: s, options: [], range: range) else { return nil }
        return ns.substring(with: m.range(at: 1))
    }

    private static func postProcess(_ s: String) -> String {
        var t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        t = t.replacingOccurrences(of: "（.+?）", with: "", options: .regularExpression)
        t = t.replacingOccurrences(of: "\n", with: " ") // ← 修正
        t = t.trimmingCharacters(in: CharacterSet(charactersIn: " 、。・-—:"))
        return t
    }
}
