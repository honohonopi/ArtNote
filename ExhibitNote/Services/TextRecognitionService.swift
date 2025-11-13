//
//  TextRecognitionService.swift
//  ArtNote
//
//  Created by Honoka Nishiyama on 2025/10/03.
//

// Live Text / OCR
import UIKit
import Vision

enum TextRecognitionError: Error {
    case noImage, handlerFailed, recognizeFailed
}

struct TextRecognitionService {
    /// 画像からテキストを抽出（日本語/英語両対応）
    static func recognizeText(from image: UIImage) async throws -> String {
        guard let cg = image.cgImage else { throw TextRecognitionError.noImage }

        return try await withCheckedThrowingContinuation { cont in
            let req = VNRecognizeTextRequest { req, err in
                if let err = err { return cont.resume(throwing: err) }
                let texts = (req.results as? [VNRecognizedTextObservation])?
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")
                cont.resume(returning: texts ?? "")
            }
            req.recognitionLanguages = ["ja-JP", "en-US"]
            req.recognitionLevel = .accurate
            req.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cg, options: [:])
            do {
                try handler.perform([req])
            } catch {
                cont.resume(throwing: TextRecognitionError.handlerFailed)
            }
        }
    }
}
