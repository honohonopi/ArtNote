//
//  RuleBasedFlyerExtractor.swift
//  ExhibitNote
//
//  Created by Honoka Nishiyama on 2026/01/06.
//

import Foundation

enum RuleBasedFlyerExtractor {

    static func extract(
        rawText: String,
        lines: [FlyerClassifiedText],
        ocrItems: [RecognizedTextItem] = [],
        basicOnly: Bool = false
    ) -> FlyerExtractionResult {
        let adjustedLines = lines.map { line in
            if looksLikePeriodLine(line.text), !looksLikeFeeText(line.text), !looksLikeScheduleText(line.text) {
                return FlyerClassifiedText(text: line.text, category: "period", confidence: max(line.confidence, 0.55))
            }
            if looksLikeFeeText(line.text), !looksLikePeriodLine(line.text), !looksLikeScheduleText(line.text) {
                return FlyerClassifiedText(text: line.text, category: "fee", confidence: max(line.confidence, 0.55))
            }
            if looksLikeScheduleText(line.text), !looksLikePeriodLine(line.text), !looksLikeFeeText(line.text) {
                return FlyerClassifiedText(text: line.text, category: "schedule", confidence: max(line.confidence, 0.55))
            }
            return line
        }

        // ① 低 confidence 行を捨てる
        let thresholds: [String: Double] = [
            "title":  0.35,
            "venue":  0.45,
            "period": 0.40,
            "url":    0.50,
            "fee":    0.45,
            "schedule": 0.45,
            "closed": 0.45,
            "reservation": 0.45,
            "specialClosedDate": 0.45,
            "specialOpenDate": 0.45,
            "specialOpeningTime": 0.45
        ]

        func isHighConfidence(_ line: FlyerClassifiedText) -> Bool {
            let th = thresholds[line.category] ?? 0.0
            return line.confidence >= th
        }

        let filteredLines: [FlyerClassifiedText] = adjustedLines.compactMap { line in
            if isHighConfidence(line) { return line }

            if DateExtractor.looksLikePeriodText(line.text) {
                print("⚠️ force-keep low-conf period line: \"\(line.text)\" ")
                return FlyerClassifiedText(
                    text: line.text,
                    category: "period",
                    confidence: max(line.confidence, 0.40)
                )
            }
            return nil
        }

        print("===== Flyer OCR classified lines (after confidence filter) =====")
        for l in filteredLines {
            let c = String(format: "%.3f", l.confidence)
            print("[flyer-use] \"\(l.text)\" -> label=\(l.category), conf=\(c)")
        }
        print("===== End of flyer classification (filtered) =====")

        let titleLines = filteredLines.filter { $0.category == "title" }.map(\.text)
        let venueLines = filteredLines.filter { $0.category == "venue" }.map(\.text)
        let urlLines = filteredLines.filter { $0.category == "url" }.map(\.text)
        let scheduleLines = filteredLines.filter { $0.category == "schedule" }.map(\.text)
        let closedLines = filteredLines.filter { $0.category == "closed" }.map(\.text)
        let reservationLines = filteredLines.filter { $0.category == "reservation" }.map(\.text)
        let specialClosedLines = filteredLines.filter { $0.category == "specialClosedDate" }.map(\.text)
        let specialOpenLines = filteredLines.filter { $0.category == "specialOpenDate" }.map(\.text)
        let specialOpeningTimeLines = filteredLines.filter { $0.category == "specialOpeningTime" }.map(\.text)

        func isClosedInfo(_ s: String) -> Bool {
            s.contains("休館") || s.contains("休園") || s.contains("休室") || s.contains("閉館")
        }

        let periodOrdered = filteredLines.filter { $0.category == "period" || looksLikePeriodLine($0.text) }
        let periodCore = periodOrdered.filter { !isClosedInfo($0.text) }
        let mergedPeriodLines = mergePeriodLines(periodCore.map(\.text))

        var dateCandidates: [(Date, Date)] = []
        if !mergedPeriodLines.isEmpty {
            for cand in mergedPeriodLines.prefix(6) {
                let cands = DateExtractor.candidates(from: cand)
                print("[period-cand] \"\(cand)\" -> \(cands.count) pairs")
                if !cands.isEmpty {
                    dateCandidates = cands
                    break
                }
            }
        }

        let periodSource: String = {
            if !mergedPeriodLines.isEmpty {
                return mergedPeriodLines.joined(separator: "\n")
            } else {
                let rawFallback = !periodOrdered.isEmpty
                return rawFallback
                ? periodOrdered.map(\.text).joined(separator: "\n")
                : rawText
            }
        }()

        if dateCandidates.isEmpty {
            dateCandidates = DateExtractor.candidates(from: periodSource)
        }

        let titleSource = shouldUseTitleLines(titleLines) ? titleLines.joined(separator: "\n") : rawText
        let venueSource = shouldUseVenueLines(venueLines) ? venueLines.joined(separator: "\n") : rawText
        let urlSource = urlLines.isEmpty ? rawText : urlLines.joined(separator: "\n")

        let titleCandidates = TitleExtractor.candidates(from: ocrItems, fallbackText: titleSource)
        let venueCandidates = VenueExtractor.candidates(from: venueSource)
        let urlCandidates = URLExtractor.extractURLs(from: urlSource)

        if basicOnly {
            return FlyerExtractionResult(
                rawText: rawText,
                classifiedLines: lines,
                titleCandidates: titleCandidates,
                venueCandidates: venueCandidates,
                venuePOI: nil,
                schedule: nil,
                dateCandidates: dateCandidates,
                urlCandidates: urlCandidates,
                admissionFees: nil,
                reservationRequired: nil
            )
        }

        let feeCandidates = filteredLines
            .filter { looksLikeFeeText($0.text) }
            .map(\.text)
        let feeSource: String = {
            if feeCandidates.isEmpty {
                return rawText
            }
            return feeCandidates.joined(separator: "\n")
        }()
        let scheduleSource = scheduleLines.isEmpty ? rawText : scheduleLines.joined(separator: "\n")
        let closedSource = closedLines.isEmpty ? rawText : closedLines.joined(separator: "\n")
        let reservationSource = reservationLines.isEmpty ? rawText : reservationLines.joined(separator: "\n")
        let specialClosedSource = specialClosedLines.isEmpty ? rawText : specialClosedLines.joined(separator: "\n")
        let specialOpenSource = specialOpenLines.isEmpty ? rawText : specialOpenLines.joined(separator: "\n")
        let specialOpeningTimeSource = specialOpeningTimeLines.isEmpty ? rawText : specialOpeningTimeLines.joined(separator: "\n")

        let fees = AdmissionFeeParser.parse(from: feeSource)
        let reservation = ReservationParser.parse(from: reservationSource)
        let schedule = ScheduleParser.parse(
            from: scheduleSource,
            closedSource: closedSource,
            specialClosedSource: specialClosedSource,
            specialOpenSource: specialOpenSource,
            specialOpeningTimeSource: specialOpeningTimeSource
        )

        return FlyerExtractionResult(
            rawText: rawText,
            classifiedLines: lines,
            titleCandidates: titleCandidates,
            venueCandidates: venueCandidates,
            venuePOI: nil,
            schedule: schedule,
            dateCandidates: dateCandidates,
            urlCandidates: urlCandidates,
            admissionFees: fees,
            reservationRequired: reservation
        )
    }

    private static func mergePeriodLines(_ lines: [String]) -> [String] {
        var merged: [String] = []
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            if let last = merged.last {
                let joiners = ["-", "―", "—", "〜", "～", "ー", "〜", "～"]
                let startsWithJoiner = joiners.contains { trimmed.hasPrefix($0) }
                let lastHasDate = trimmedDateLike(last)
                let lastEndsWithJoiner = joiners.contains { last.hasSuffix($0) }
                if (startsWithJoiner && lastHasDate && trimmedDateLike(trimmed)) || (lastEndsWithJoiner && trimmedDateLike(trimmed)) {
                    merged.removeLast()
                    let joined = last + trimmed
                    merged.append(joined)
                    continue
                }
            }
            merged.append(trimmed)
        }
        return merged
    }

    private static func trimmedDateLike(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.contains("年") || t.contains("/") || t.contains("-")
    }

    private static func looksLikePeriodLine(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return false }
        if t.contains("会期") || t.contains("開催") || t.contains("期間") { return true }
        if t.contains("年") || t.contains("月") || t.contains("日") { return true }
        let datePattern = #"\d{4}[/\.-]\d{1,2}[/\.-]\d{1,2}"#
        if t.range(of: datePattern, options: .regularExpression) != nil { return true }
        let joinerPrefix = ["-", "―", "—", "〜", "～", "ー"]
        if joinerPrefix.contains(where: { t.hasPrefix($0) }) {
            return t.contains("月") || t.contains("日")
        }
        return false
    }

    private static func looksLikeFeeText(_ text: String) -> Bool {
        let t = text.replacingOccurrences(of: " ", with: "")
        if t.contains("円") || t.contains("無料") { return true }
        if t.contains("前売") || t.contains("当日") || t.contains("一般") || t.contains("高校") || t.contains("学生") || t.contains("大学") || t.contains("中学生") || t.contains("小学生") || t.contains("子供") { return true }
        let pricePattern = #"[0-9]{1,3}(?:,[0-9]{3})+円|[0-9]{2,6}円"#
        return t.range(of: pricePattern, options: .regularExpression) != nil
    }

    private static func looksLikeScheduleText(_ text: String) -> Bool {
        let t = text.replacingOccurrences(of: " ", with: "")
        if t.contains("開館") || t.contains("開場") || t.contains("最終入場") || t.contains("最終入館") { return true }
        let timePattern = #"\d{1,2}:\d{2}"#
        return t.range(of: timePattern, options: .regularExpression) != nil
    }

    private static func shouldUseTitleLines(_ lines: [String]) -> Bool {
        let candidates = lines.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if candidates.isEmpty { return false }
        return candidates.contains { line in
            line.contains("展") || line.contains("展覧会") || line.count >= 6
        }
    }

    private static func shouldUseVenueLines(_ lines: [String]) -> Bool {
        let candidates = lines.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if candidates.isEmpty { return false }
        return candidates.contains { line in
            line.contains("会場") || line.contains("美術館") || line.contains("ギャラリー") || line.contains("博物館") || line.contains("ホール")
        }
    }
}
