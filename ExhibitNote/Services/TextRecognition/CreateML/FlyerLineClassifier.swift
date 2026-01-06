//
//  FlyerLineClassifier.swift
//  ExhibitNote
//
//  Created by Honoka Nishiyama on 2026/01/06.
//

import UIKit
import NaturalLanguage

// NLModel分類だけ（Create ML）
struct FlyerClassifiedText {
    let text: String
    let category: String
    let confidence: Double
}

enum FlyerLineClassifier {

    enum Error: Swift.Error {
        case modelNotFound
        case ocrFailed
    }

    private static let model: NLModel? = {
        let url = TextClassifier_flyer.urlOfModelInThisBundle
        do {
            let nlModel = try NLModel(contentsOf: url)
            print("✅ Loaded NLModel for flyer from \(url.lastPathComponent)")
            return nlModel
        } catch {
            print("⚠️ Failed to load NLModel for flyer: \(error)")
            return nil
        }
    }()

    static func classify(from image: UIImage) async throws -> [FlyerClassifiedText] {
        // 1) OCR
        let items = try await OCRTextRecognizer.recognizeText(from: image)
        return try classify(lines: items.map(\.text))
    }

    static func classify(lines: [String]) throws -> [FlyerClassifiedText] {
        guard let model else { throw Error.modelNotFound }

        return lines.compactMap { line in
            let text = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }
            let hypotheses = model.predictedLabelHypotheses(for: text, maximumCount: 4)
            if let (bestLabel, prob) = hypotheses.max(by: { $0.value < $1.value }) {
                return FlyerClassifiedText(text: text, category: bestLabel, confidence: prob)
            }
            return FlyerClassifiedText(text: text, category: "unknown", confidence: 0)
        }
    }
}
