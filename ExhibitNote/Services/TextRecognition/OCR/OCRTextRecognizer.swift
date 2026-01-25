//
//  OCRTextRecognizer.swift
//  ExhibitNote
//
//  Created by Honoka Nishiyama on 2026/01/06.
//

import UIKit
import Vision

// Vision OCRだけ
struct RecognizedTextItem {
    let text: String
    let confidence: Float
    let boundingBoxHeight: CGFloat
}

enum OCRTextRecognizer {

    enum Error: Swift.Error {
        case invalidImage
        case noResults
    }

    static func recognizeText(from image: UIImage) async throws -> [RecognizedTextItem] {
        guard let cgImage = image.cgImage else { throw Error.invalidImage }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error { return continuation.resume(throwing: error) }

                let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                let items: [RecognizedTextItem] = observations.compactMap { obs in
                    guard let best = obs.topCandidates(1).first else { return nil }
                    return RecognizedTextItem(
                        text: best.string,
                        confidence: best.confidence,
                        boundingBoxHeight: obs.boundingBox.height
                    )
                }

                if items.isEmpty {
                    continuation.resume(throwing: Error.noResults)
                } else {
                    continuation.resume(returning: items)
                }
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["ja-JP", "en-US"]

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
