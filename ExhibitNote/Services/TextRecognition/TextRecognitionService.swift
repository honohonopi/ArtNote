//
//  TextRecognitionService.swift
//  ExhibitNote
//
//  Created by Honoka Nishiyama on 2025/10/03.
//

import Foundation
import UIKit

enum TextRecognitionError: Error {
    case noImage
    case handlerFailed
    case recognizeFailed
    case aiResponseInvalid
}

struct TextRecognitionService {

    static func classifyFlyer(from image: UIImage) async throws
    -> (rawText: String, lines: [FlyerClassifiedText], usedFoundationModel: Bool, ocrItems: [RecognizedTextItem]) {
        let items = try await OCRTextRecognizer.recognizeText(from: image)
        let fullText = items.map(\.text).joined(separator: "\n")

        let lineStrings = items
            .map(\.text)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var usedFoundationModel = false
        if #available(iOS 26.0, *) {
            print("🤖 FoundationModels available: \(FoundationModelFlyerClassifier.isAvailable) (\(FoundationModelFlyerClassifier.availabilityDescription))")
        }
        if #available(iOS 26.0, *), FoundationModelFlyerClassifier.isAvailable {
            do {
                let lines = try await FoundationModelFlyerClassifier.classifyLines(lineStrings)
                print("🤖 FoundationModels classify success: \(lines.count) lines")
                usedFoundationModel = true
                return (fullText, lines, usedFoundationModel, items)
            } catch {
                print("⚠️ FoundationModels classify failed: \(error)")
            }
        }

        do {
            let lines = try FlyerLineClassifier.classify(lines: lineStrings)
            return (fullText, lines, usedFoundationModel, items)
        } catch {
            let fallback = lineStrings.map {
                FlyerClassifiedText(text: $0, category: "other", confidence: 0)
            }
            return (fullText, fallback, usedFoundationModel, items)
        }
    }

    static func extractFlyerFields(from image: UIImage, basicOnly: Bool = false) async throws -> FlyerExtractionResult {
        let (raw, lines, _, items) = try await classifyFlyer(from: image)
        return RuleBasedFlyerExtractor.extract(rawText: raw, lines: lines, ocrItems: items, basicOnly: basicOnly)
    }

    static func extractFlyerFieldsWithAI(from image: UIImage) async throws -> FlyerExtractionResult {
        try await GeminiFlyerExtractor.extract(from: image)
    }

    static func extractFlyerFieldsWithMeta(from image: UIImage, basicOnly: Bool = false) async throws
    -> (result: FlyerExtractionResult, usedFoundationModel: Bool) {
        let (raw, lines, usedFoundationModel, items) = try await classifyFlyer(from: image)
        let result = RuleBasedFlyerExtractor.extract(rawText: raw, lines: lines, ocrItems: items, basicOnly: basicOnly)
        return (result, usedFoundationModel)
    }

    // ExtraInfo は flyerBasic に統合済み（単一リクエスト運用）
}
