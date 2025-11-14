//
//  TextRecognitionService.swift
//  ArtNote
//
//  Created by Honoka Nishiyama on 2025/10/03.
//

// Live Text / OCR
import UIKit
import Vision
import CoreML
import NaturalLanguage

enum TextRecognitionError: Error {
    case noImage, handlerFailed, recognizeFailed
}

struct TextRecognitionService {
    
    private static let flyerNLModel: NLModel? = {
        // Create ML が生成した CoreML モデルの URL
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
    
    /// Create ML で学習したフライヤー用テキスト分類モデルの 1 行分の結果
    struct FlyerClassifiedText: Identifiable {
        let id = UUID()
        let text: String
        let label: String      // 例: "title", "venue", "period", "url", "other" など
        let confidence: Double
    }
    
    /// 1枚のポスター画像から、
    /// 1) OCRで全文テキストを取得
    /// 2) 行ごとに Create ML モデルでラベル分類
    static func classifyFlyer(from image: UIImage) async throws
    -> (rawText: String, lines: [FlyerClassifiedText]) {

        let fullText = try await recognizeText(from: image)
        var results: [FlyerClassifiedText] = []

        let lineStrings = fullText
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        guard let nlModel = flyerNLModel else {
            // モデルがロードできない場合は、ラベル=otherでそのまま返す
            for line in lineStrings {
                results.append(
                    FlyerClassifiedText(
                        text: line,
                        label: "other",
                        confidence: 0.0
                    )
                )
            }
            return (fullText, results)
        }

        // NLModel で各行を予測
        for line in lineStrings {
            let hyps = nlModel.predictedLabelHypotheses(for: line, maximumCount: 4)
            if let (bestLabel, prob) = hyps.max(by: { $0.value < $1.value }) {
                print("[flyer-NL] \"\(line)\" -> \(bestLabel), conf=\(prob)")
                results.append(
                    FlyerClassifiedText(
                        text: line,
                        label: bestLabel,
                        confidence: prob
                    )
                )
            } else {
                print("⚠️ flyer-NL produced no hypotheses for \"\(line)\"")
                results.append(
                    FlyerClassifiedText(
                        text: line,
                        label: "other",
                        confidence: 0.0
                    )
                )
            }
        }

        return (fullText, results)
    }

    // MARK: - フィールド抽出の結果モデル
    struct FlyerExtractionResult {
        let rawText: String
        let classifiedLines: [FlyerClassifiedText]
        let titleCandidates: [String]
        let venueCandidates: [String]
        let dateCandidates: [(Date, Date)]
        let urlCandidates: [String]
    }
    
    static func extractFlyerFields(from image: UIImage) async throws -> FlyerExtractionResult {
        let (raw, lines) = try await classifyFlyer(from: image)
        
        // ① 低 confidence 行を捨てる ----------------------------------
        // ラベルごとのしきい値（暫定値。運用しながら調整）
        let thresholds: [String: Double] = [
            "title":  0.35,
            "venue":  0.45,
            "period": 0.40,
            "url":    0.50
        ]
        
        func isHighConfidence(_ line: FlyerClassifiedText) -> Bool {
            let th = thresholds[line.label] ?? 0.0   // 未知ラベルはフィルタしない
            return line.confidence >= th
        }
        
        let filteredLines = lines.filter(isHighConfidence)
        
        print("===== Flyer OCR classified lines (after confidence filter) =====")
        for l in filteredLines {
            let c = String(format: "%.3f", l.confidence)
            print("[flyer-use] \"\(l.text)\" -> label=\(l.label), conf=\(c)")
        }
        print("===== End of flyer classification (filtered) =====")
        
        // ② ラベルごとにテキストを集める ----------------------------
        let titleLines  = filteredLines.filter { $0.label == "title"  }.map(\.text)
        let venueLines  = filteredLines.filter { $0.label == "venue"  }.map(\.text)
        let periodLines = filteredLines.filter { $0.label == "period" }.map(\.text)
        let urlLines    = filteredLines.filter { $0.label == "url"    }.map(\.text)
        
        // ③ ラベル付き行が空なら、従来どおり全文を使って解析するフォールバック
        let titleSource  = titleLines.isEmpty  ? raw : titleLines.joined(separator: "\n")
        let venueSource  = venueLines.isEmpty  ? raw : venueLines.joined(separator: "\n")
        let periodSource = periodLines.isEmpty ? raw : periodLines.joined(separator: "\n")
        let urlSource    = urlLines.isEmpty    ? raw : urlLines.joined(separator: "\n")
        
        // ④ 既存のヘルパー群をそのまま活かす
        let titleCandidates = TitleExtractionService.candidates(from: titleSource)
        let venueCandidates = VenueExtractionService.candidates(from: venueSource)
        let dateCandidates  = DateParsingService.candidates(from: periodSource)
        let urlCandidates   = extractURLs(from: urlSource)
        
        return FlyerExtractionResult(
            rawText: raw,
            classifiedLines: lines,
            titleCandidates: titleCandidates,
            venueCandidates: venueCandidates,
            dateCandidates: dateCandidates,
            urlCandidates: urlCandidates
        )
    }
    
    // MARK: - URL 抽出ヘルパー
    /// テキストの中から http / https の URL だけを抜く簡易ヘルパー
    private static func extractURLs(from text: String) -> [String] {
        let pattern = #"https?://[^\s]+"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return []
        }
        let ns = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: ns.length))
            .map { ns.substring(with: $0.range) }
    }
    
    // MARK: - 共通 OCR
    /// 画像からテキストを抽出（日本語/英語両対応）
    static func recognizeText(from image: UIImage) async throws -> String {
        guard let cg = image.cgImage else { throw TextRecognitionError.noImage }
        
        return try await withCheckedThrowingContinuation { cont in
            let req = VNRecognizeTextRequest { req, err in
                if let err = err {
                    cont.resume(throwing: err)
                    return
                }
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

