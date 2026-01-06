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
    -> (rawText: String, lines: [FlyerClassifiedText]) {
        let items = try await OCRTextRecognizer.recognizeText(from: image)
        let fullText = items.map(\.text).joined(separator: "\n")

        let lineStrings = items
            .map(\.text)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        do {
            let lines = try FlyerLineClassifier.classify(lines: lineStrings)
            return (fullText, lines)
        } catch {
            let fallback = lineStrings.map {
                FlyerClassifiedText(text: $0, category: "other", confidence: 0)
            }
            return (fullText, fallback)
        }
    }

    static func extractFlyerFields(from image: UIImage) async throws -> FlyerExtractionResult {
        let (raw, lines) = try await classifyFlyer(from: image)
        return RuleBasedFlyerExtractor.extract(rawText: raw, lines: lines)
    }

    static func extractFlyerFieldsWithAI(from image: UIImage) async throws -> FlyerExtractionResult {
        try await GeminiFlyerExtractor.extract(from: image)
    }

    // ExtraInfo は flyerBasic に統合済み（単一リクエスト運用）
}
