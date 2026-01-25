//
//  VenueExtractor.swift
//  ArtNote
//
//  Created by Honoka Nishiyama on 2025/10/03.
//

// 会場名推定
import Foundation

struct VenueExtractor {
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
            var baseScore = 0

            // 「会場: ～」など、会場を示唆する語
            if hintWords.contains(where: {
                clean.replacingOccurrences(of: " ", with: "")
                    .contains($0.replacingOccurrences(of: " ", with: ""))
            }) {
                baseScore += 3
            }

            // 美術館/ギャラリーなどを含んでいたら +2
            if keywordsJP.contains(where: { clean.localizedCaseInsensitiveContains($0) }) {
                baseScore += 2
            }
            if keywordsEN.contains(where: { clean.localizedCaseInsensitiveContains($0) }) {
                baseScore += 2
            }

            // まず「◯◯美術館」「◯◯ギャラリー」などを抜き出してスコアリング
            if let m = regexMatch(
                clean,
                pattern: "(.{0,30}?(美術館|博物館|ミュージアム|ギャラリー|資料館|記念館))"
            ) {
                var cand = postProcess(m)
                cand = trimToVenueSegment(cand, keywordsJP + keywordsEN)

                var score = baseScore + min(cand.count / 4, 4)

                // 語尾が「美術館」などで終わっているとさらに優先
                if keywordsJP.contains(where: { cand.hasSuffix($0) }) ||
                    keywordsEN.contains(where: { cand.hasSuffix($0) }) {
                    score += 3
                }

                scored.append((cand, score))
                continue
            }

            // 「会場: 〜」パターン（\s は \\s でエスケープ）
            if let m = regexMatch(clean, pattern: "(?:会場[:：\\s]+)(.+)") {
                var cand = postProcess(m)
                cand = trimToVenueSegment(cand, keywordsJP + keywordsEN)

                var score = baseScore + 2 + min(cand.count / 5, 3)
                if keywordsJP.contains(where: { cand.hasSuffix($0) }) ||
                    keywordsEN.contains(where: { cand.hasSuffix($0) }) {
                    score += 3
                }

                scored.append((cand, score))
                continue
            }
        }

        // 同じ文字列ごとに最大スコアをまとめる
        let grouped: [(str: String, score: Int)] = Dictionary(grouping: scored, by: { $0.str })
            .map { key, values in
                (key, values.map { $0.score }.max() ?? 0)
            }
            .sorted { $0.score > $1.score }   // スコア順にソート（降順）
        
        // 候補がなければ空配列
        guard let best = grouped.first else { return [] }
        
        let bestScore = best.score
        // 1位との差が小さいものだけを「候補」として残す
        let thresholdDiff = 1 // スコア差(適宜変更)
        
        let closeCandidates = grouped.filter { candidate in
            (bestScore - candidate.score) <= thresholdDiff
        }
        
        // 長さフィルタは今までどおり
        let names = closeCandidates
            .map { $0.str }
            .filter { $0.count >= 2 && $0.count <= 40 }
        
        return names
    }

    static func best(from text: String) -> String? {
        candidates(from: text).first
    }

    // MARK: - 内部ヘルパー

    private static func normalize(_ s: String) -> String {
        var s = s
        s = s.replacingOccurrences(of: "https?://[A-Za-z0-9./_-]+",
                                   with: "",
                                   options: .regularExpression)
        s = s.replacingOccurrences(of: "[0-9]{2}:[0-9]{2}",
                                   with: "",
                                   options: .regularExpression)
        s = s.replacingOccurrences(of: "TEL[:：]?\\s*[0-9-]+",
                                   with: "",
                                   options: .regularExpression)
        return s
    }

    private static func regexMatch(_ s: String, pattern: String) -> String? {
        guard let r = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns = s as NSString
        let range = NSRange(location: 0, length: ns.length)
        guard let m = r.firstMatch(in: s, options: [], range: range) else { return nil }
        return ns.substring(with: m.range(at: 1))
    }

    /// 先頭と末尾のノイズを削る
    private static func postProcess(_ s: String) -> String {
        var t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        // カッコ内を削除
        t = t.replacingOccurrences(of: "（.+?）", with: "", options: .regularExpression)
        // 改行 → スペース
        t = t.replacingOccurrences(of: "\n", with: " ")
        // 先頭末尾の記号
        t = t.trimmingCharacters(in: CharacterSet(charactersIn: " 、。・-—:"))
        return t
    }

    /// 「共催：〜 印刷博物館、一般社団法人〜」のような行から
    /// 最後の「印刷博物館」「◯◯Gallery」の部分だけを切り出す
    private static func trimToVenueSegment(_ s: String, _ markers: [String]) -> String {
        for m in markers {
            if let range = s.range(of: m) {
                // キーワードの直前にある区切り文字（スペース・読点など）を探す
                let before = s[..<range.lowerBound]
                let separators = " 　、，,/／:：()（）・｜|［］[]"
                let startIndex = before.lastIndex(where: { c in
                    separators.contains(c)
                }).map { s.index(after: $0) } ?? s.startIndex

                let endIndex = range.upperBound
                let sub = String(s[startIndex..<endIndex])
                return sub.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return s
    }
}
