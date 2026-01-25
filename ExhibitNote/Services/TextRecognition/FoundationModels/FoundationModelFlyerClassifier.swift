//
//  FoundationModelFlyerClassifier.swift
//  ExhibitNote
//
//  Created by Codex on 2026/01/xx.
//

import Foundation

#if canImport(FoundationModels)
import FoundationModels

@available(iOS 26.0, *)
enum FoundationModelFlyerClassifier {
    enum Error: Swift.Error {
        case unavailable(String)
        case invalidResponse
    }

    @Generable
    struct ClassifiedLine {
        @Generable
        enum Kind: String {
            case title
            case venue
            case period
            case url
            case fee
            case schedule
            case closed
            case reservation
            case specialClosedDate
            case specialOpenDate
            case specialOpeningTime
            case other
        }

        @Guide(description: "Pick one category for the line.")
        var kind: Kind
        var text: String
        @Guide(description: "Confidence score between 0.0 and 1.0.", .range(0.0...1.0))
        var confidence: Double
    }

    @Generable
    struct OCRClassificationResult {
        var lines: [ClassifiedLine]
    }

    static var isAvailable: Bool { SystemLanguageModel.default.isAvailable }

    static var availabilityDescription: String {
        String(describing: SystemLanguageModel.default.availability)
    }

    static func isSupportedButDisabled() -> Bool {
        switch SystemLanguageModel.default.availability {
        case .available:
            return false
        case .unavailable(let reason):
            let reasonText = String(describing: reason)
            return reasonText.contains("modelNotReady") || reasonText.contains("notEnabled")
        @unknown default:
            return false
        }
    }

    static func classifyOCRLines(_ lines: [String]) async throws -> OCRClassificationResult {
        guard SystemLanguageModel.default.isAvailable else {
            throw Error.unavailable(availabilityDescription)
        }
        print("🤖 FoundationModels: using SystemLanguageModel")
        let session = LanguageModelSession()
        let input = lines.enumerated().map { "[\($0.offset)] \($0.element)" }.joined(separator: "\n")
        let prompt = """
        You are an OCR line classifier for Japanese exhibition posters.
        For each input line, assign one kind from:
        title, venue, period, url, fee, schedule, closed, reservation, specialClosedDate, specialOpenDate, specialOpeningTime, other.
        Keep the original text intact. Provide a confidence between 0.0 and 1.0.
        If unsure, use other with low confidence.
        Output must contain the same number of lines as the input. Keep line order.

        Classification hints:
        - period: lines containing dates or date ranges (会期/開催期間/2026年1月16日〜3月29日, "-3月29日" continuation)
        - schedule: regular opening hours (開館時間, 開館 10:00〜17:00, 最終入場)
        - closed: regular closed weekdays (休館日/休館曜日 with weekday names)
        - specialClosedDate: special closure dates (特別休館日, 臨時休館, 休館日 2026-01-01)
        - specialOpenDate: special open dates (特別開館日, 臨時開館, 祝日開館日)
        - specialOpeningTime: special opening hours (特別開館時間, 臨時の開館時間, 夜間開館)
        - fee: admission fee lines, including labels (一般/学生/子供/前売/当日) and price lines with 円/無料
        - url: lines containing URLs, web domains, or "www"
        - venue: venue name lines even if prefixed with "会場"
        - title: main exhibition title line; avoid labeling generic phrases or paragraph sentences as title

        Lines:
        \(input)
        """
        let response = try await session.respond(to: prompt, generating: OCRClassificationResult.self)
        return response.content
    }

    static func classifyLines(_ lines: [String]) async throws -> [FlyerClassifiedText] {
        let cleaned = lines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if cleaned.isEmpty { return [] }
        let filtered = filterLinesForBasicInfo(cleaned)
        let capped = capLinesForContext(filtered)
        let result = try await classifyOCRLines(capped)
        let minCount = min(result.lines.count, capped.count)
        if result.lines.count != capped.count {
            print("⚠️ FoundationModels line count mismatch: got \(result.lines.count), expected \(capped.count)")
        }
        let mapped = result.lines.prefix(minCount).enumerated().map { index, line in
            FlyerClassifiedText(text: capped[index], category: line.kind.rawValue, confidence: line.confidence)
        }
        if minCount < capped.count {
            let fallback = capped[minCount...].map {
                FlyerClassifiedText(text: $0, category: "other", confidence: 0)
            }
            return mapped + fallback
        }
        return mapped
    }

    private static func filterLinesForBasicInfo(_ lines: [String]) -> [String] {
        let keywordPatterns = [
            "会期", "開催", "期間", "会場", "場所", "住所", "アクセス",
            "展覧会", "企画展", "特別展", "個展", "展",
            "ギャラリー", "美術館", "博物館", "ホール", "センター"
        ]
        let urlHints = ["http", "www", ".jp", ".com", ".net"]
        let addressHints = ["都", "道", "府", "県", "市", "区", "町", "村", "丁目", "番地", "号"]
        let datePattern = #"\d{4}年|\d{1,2}月\d{1,2}日|\d{4}[/\.-]\d{1,2}[/\.-]\d{1,2}"#
        let rangePattern = #"[〜～\-—]"#
        let timePattern = #"\d{1,2}:\d{2}"#

        func matchesPattern(_ text: String, _ pattern: String) -> Bool {
            text.range(of: pattern, options: .regularExpression) != nil
        }

        var indices = Set<Int>()
        let headCount = min(6, lines.count)
        for idx in 0..<headCount { indices.insert(idx) }

        for (idx, line) in lines.enumerated() {
            if keywordPatterns.contains(where: { line.contains($0) }) ||
                urlHints.contains(where: { line.lowercased().contains($0) }) ||
                addressHints.contains(where: { line.contains($0) }) ||
                matchesPattern(line, datePattern) ||
                matchesPattern(line, rangePattern) ||
                matchesPattern(line, timePattern) {
                indices.insert(idx)
                if idx > 0 { indices.insert(idx - 1) }
                if idx + 1 < lines.count { indices.insert(idx + 1) }
            }
        }

        let sorted = indices.sorted()
        let maxLines = 24
        let filtered = sorted.prefix(maxLines).map { lines[$0] }
        if filtered.count < lines.count {
            print("⚠️ FoundationModels input filtered: \(filtered.count)/\(lines.count) lines")
        }
        return filtered.isEmpty ? lines : filtered
    }

    private static func capLinesForContext(_ lines: [String]) -> [String] {
        let maxChars = 2600
        var result: [String] = []
        var total = 0
        for line in lines {
            if total + line.count > maxChars { break }
            result.append(line)
            total += line.count
        }
        if result.count < lines.count {
            print("⚠️ FoundationModels input truncated: \(result.count)/\(lines.count) lines")
        }
        return result
    }
}
#else
enum FoundationModelFlyerClassifier {
    enum Error: Swift.Error {
        case unavailable(String)
    }

    static var isAvailable: Bool { false }
    static var availabilityDescription: String { "FoundationModels not available" }

    static func classifyLines(_ lines: [String]) async throws -> [FlyerClassifiedText] {
        throw Error.unavailable(availabilityDescription)
    }
}
#endif
