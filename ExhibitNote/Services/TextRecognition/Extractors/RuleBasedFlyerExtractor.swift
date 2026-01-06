//
//  RuleBasedFlyerExtractor.swift
//  ExhibitNote
//
//  Created by Honoka Nishiyama on 2026/01/06.
//

import Foundation

enum RuleBasedFlyerExtractor {

    static func extract(rawText: String, lines: [FlyerClassifiedText]) -> FlyerExtractionResult {
        // ① 低 confidence 行を捨てる
        let thresholds: [String: Double] = [
            "title":  0.35,
            "venue":  0.45,
            "period": 0.40,
            "url":    0.50
        ]

        func isHighConfidence(_ line: FlyerClassifiedText) -> Bool {
            let th = thresholds[line.category] ?? 0.0
            return line.confidence >= th
        }

        let filteredLines: [FlyerClassifiedText] = lines.compactMap { line in
            if isHighConfidence(line) { return line }

            if DateParsingService.looksLikePeriodText(line.text) {
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

        func isClosedInfo(_ s: String) -> Bool {
            s.contains("休館") || s.contains("休園") || s.contains("休室") || s.contains("閉館")
        }

        let periodRanked = filteredLines
            .filter { $0.category == "period" }
            .sorted { $0.confidence > $1.confidence }

        let periodCore = periodRanked.filter { !isClosedInfo($0.text) }

        var dateCandidates: [(Date, Date)] = []
        if !periodCore.isEmpty {
            for cand in periodCore.prefix(6) {
                let cands = DateParsingService.candidates(from: cand.text)
                print("[period-cand] \"\(cand.text)\" conf=\(String(format: "%.3f", cand.confidence)) -> \(cands.count) pairs")
                if !cands.isEmpty {
                    dateCandidates = cands
                    break
                }
            }
        }

        let periodSource: String = {
            if !periodCore.isEmpty {
                return periodCore.map(\.text).joined(separator: "\n")
            } else {
                let rawFallback = filteredLines.first(where: { $0.category == "period" }) != nil
                return rawFallback
                ? filteredLines.filter { $0.category == "period" }.map(\.text).joined(separator: "\n")
                : rawText
            }
        }()

        if dateCandidates.isEmpty {
            dateCandidates = DateParsingService.candidates(from: periodSource)
        }

        let titleSource = titleLines.isEmpty ? rawText : titleLines.joined(separator: "\n")
        let venueSource = venueLines.isEmpty ? rawText : venueLines.joined(separator: "\n")
        let urlSource = urlLines.isEmpty ? rawText : urlLines.joined(separator: "\n")

        let titleCandidates = TitleExtractionService.candidates(from: titleSource)
        let venueCandidates = VenueExtractionService.candidates(from: venueSource)
        let urlCandidates = URLExtractor.extractURLs(from: urlSource)

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
}
