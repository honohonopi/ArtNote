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

enum TextRecognitionError: Error {
    case noImage, handlerFailed, recognizeFailed
}

struct TextRecognitionService {
    /// Create ML で学習したフライヤー用テキスト分類モデルの 1 行分の結果
    struct FlyerClassifiedText: Identifiable {
        let id = UUID()
        let text: String
        let label: String      // 例: "title", "venue", "period", "url", "other" など
    }
    
    /// Create ML で生成されたモデルクラス
    private static let flyerModel: TextClassifier_flyer? = {
        do {
            let config = MLModelConfiguration()
            return try TextClassifier_flyer(configuration: config)
        } catch {
            print("⚠️ TextClassifier_flyer load failed: \(error)")
            return nil
        }
    }()
    
    /// 1枚のポスター画像から、
    /// 1) OCRで全文テキストを取得
    /// 2) 行ごとに Create ML モデルでラベル分類
    static func classifyFlyer(from image: UIImage) async throws -> (rawText: String, lines: [FlyerClassifiedText]) {
        // まず既存の OCR 処理を使って全文を取る
        let fullText = try await recognizeText(from: image)
        
        print("===== Flyer OCR raw text (全文) =====")
        print(fullText)
        print("===== End of raw text =====")
        
        guard let model = flyerModel else {
            // モデルが読み込めなかった場合は、ラベル = "other" で返す
            let lines = fullText
                .split(whereSeparator: \.isNewline)
                .map { String($0).trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .map { FlyerClassifiedText(text: $0, label: "other") }
            print("⚠️ flyerModel == nil → 全行 other 扱い")
            for l in lines {
                print("[flyer] \(l.text)  ->  label=other, conf=1.0")
            }
            return (fullText, lines)
        }
        
        var results: [FlyerClassifiedText] = []
        let lineStrings = fullText
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        print("===== Flyer OCR classified lines =====")
        
        for line in lineStrings {
            do {
                let prediction = try model.prediction(text: line)
                let label = prediction.label                      // Create ML のラベル（String）
                
                print("[flyer] \"\(line)\"  ->  label=\(label)")
                
                results.append(FlyerClassifiedText(text: line,
                                                   label: label))
            } catch {
                print("⚠️ flyer prediction failed for '\(line)': \(error)")
                results.append(FlyerClassifiedText(text: line,
                                                   label: "other"))
            }
        }
        
        print("===== End of flyer classification =====")
        
        return (fullText, results)
    }
    
    /// TextClassifier_flyer のラベルに応じて、
    /// 展覧会名・会場・会期・URL の候補をまとめて返す便利メソッド
    /// （ラベル名は Create ML で付けたラベルに合わせて変更してね）
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
        
        // ★ここが TextClassifier_flyer の「ラベル名」に依存します！
        //   Create ML のラベルに合わせて "title" / "venue" / "period" / "url" を
        //   必要に応じて書き換えてください。
        let titleLines  = lines.filter { $0.label == "title" }.map(\.text)
        let venueLines  = lines.filter { $0.label == "venue" }.map(\.text)
        let periodLines = lines.filter { $0.label == "period" }.map(\.text)
        let urlLines    = lines.filter { $0.label == "url" }.map(\.text)
        
        // ラベル付き行が空なら、従来どおり全文を使って解析するフォールバック
        let titleSource  = titleLines.isEmpty  ? raw : titleLines.joined(separator: "\n")
        let venueSource  = venueLines.isEmpty  ? raw : venueLines.joined(separator: "\n")
        let periodSource = periodLines.isEmpty ? raw : periodLines.joined(separator: "\n")
        let urlSource    = urlLines.isEmpty    ? raw : urlLines.joined(separator: "\n")
        
        // 既存のヘルパー群をそのまま活かす
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
