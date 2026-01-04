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
import GoogleGenerativeAI

enum TextRecognitionError: Error {
    case noImage, handlerFailed, recognizeFailed, aiResponseInvalid
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
        let venuePOI: String?
        let dateCandidates: [(Date, Date)]
        let urlCandidates: [String]
    }

    private struct GeminiFlyerResponse: Decodable {
        let title: String?
        let venue: String?
        let venuePoi: String?
        let periodText: String?
        let startDate: String?
        let endDate: String?
        let url: String?
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
        
        // ★ period ラインについて、confidence が低くても looksLikePeriodText を満たせば残す
        // ★ period ラインについて、confidence が低くても looksLikePeriodText を満たせば残す
        let filteredLines: [FlyerClassifiedText] = lines.compactMap { line in
            // 高信頼ならそのまま
            if isHighConfidence(line) {
                return line
            }

            // ★ 期間っぽい文字列 → 強制的に period として採用
            if DateParsingService.looksLikePeriodText(line.text) {
                print("⚠️ force-keep low-conf period line: \"\(line.text)\" ")

                // ★ label を period に上書きしたうえで残す
                return FlyerClassifiedText(
                    text: line.text,
                    label: "period",
                    confidence: max(line.confidence, 0.40)   // しきい値扱いにする（任意）
                )
            }
            // 上記以外は破棄
            return nil
        }
        
        print("===== Flyer OCR classified lines (after confidence filter) =====")
        for l in filteredLines {
            let c = String(format: "%.3f", l.confidence)
            print("[flyer-use] \"\(l.text)\" -> label=\(l.label), conf=\(c)")
        }
        print("===== End of flyer classification (filtered) =====")
        
        // ② ラベルごとにテキストを集める ----------------------------
        let titleLines  = filteredLines.filter { $0.label == "title"  }.map(\.text)
        let venueLines  = filteredLines.filter { $0.label == "venue"  }.map(\.text)
        let urlLines    = filteredLines.filter { $0.label == "url"    }.map(\.text)
        
        // === period 強化 ===
        // 「休館日/休館/休園/休室/閉館」など休館情報を含む行は period 候補から除外
        func isClosedInfo(_ s: String) -> Bool {
            // 必要に応じてワード追加
            return s.contains("休館") || s.contains("休園") || s.contains("休室") || s.contains("閉館")
        }

        // conf の高い順に並べ、休館系を除外した period ラインを作る
        let periodRanked = filteredLines
            .filter { $0.label == "period" }
            .sorted { $0.confidence > $1.confidence }

        let periodCore = periodRanked.filter { !isClosedInfo($0.text) }

        // conf 上位から順に DateParsingService へ投げ、最初にパースできた候補群を採用
        var dateCandidates: [(Date, Date)] = []
        if !periodCore.isEmpty {
            // 最大 6 行まで試す（必要なら調整）
            for cand in periodCore.prefix(6) {
                let cands = DateParsingService.candidates(from: cand.text)
                print("[period-cand] \"\(cand.text)\" conf=\(String(format: "%.3f", cand.confidence)) -> \(cands.count) pairs")
                if !cands.isEmpty {
                    dateCandidates = cands
                    break
                }
            }
        }

        // どれもパースできなかったら、従来フォールバック（period ライン全結合 or 生テキスト）
        let periodSource: String = {
            if !periodCore.isEmpty {
                return periodCore.map(\.text).joined(separator: "\n")
            } else {
                let rawFallback = filteredLines.first(where: { $0.label == "period" }) != nil
                return rawFallback
                    ? filteredLines.filter { $0.label == "period" }.map(\.text).joined(separator: "\n")
                    : raw
            }
        }()

        if dateCandidates.isEmpty {
            // まとめ文字列からも試す（行跨ぎ・装飾の影響に強い）
            dateCandidates = DateParsingService.candidates(from: periodSource)
        }
        // === ここまで period 強化 ===
        
        // ③ ラベル付き行が空なら、従来どおり全文を使って解析するフォールバック
        let titleSource  = titleLines.isEmpty  ? raw : titleLines.joined(separator: "\n")
        let venueSource  = venueLines.isEmpty  ? raw : venueLines.joined(separator: "\n")
        let urlSource    = urlLines.isEmpty    ? raw : urlLines.joined(separator: "\n")
        
        // ④ 既存のヘルパー群をそのまま活かす
        let titleCandidates = TitleExtractionService.candidates(from: titleSource)
        let venueCandidates = VenueExtractionService.candidates(from: venueSource)
        let urlCandidates   = extractURLs(from: urlSource)
        
        return FlyerExtractionResult(
            rawText: raw,
            classifiedLines: lines,
            titleCandidates: titleCandidates,
            venueCandidates: venueCandidates,
            venuePOI: nil,
            dateCandidates: dateCandidates,
            urlCandidates: urlCandidates
        )
    }

    // MARK: - Gemini
    /// Gemini を使ったポスター情報抽出（JSON で返す）
    static func extractFlyerFieldsWithAI(from image: UIImage) async throws -> FlyerExtractionResult {
        let model = GenerativeModel(name: "gemini-2.5-flash-lite", apiKey: APIKey.default)
        let prompt = """
        You are extracting exhibition information from a poster image.

        Respond ONLY in JSON (no code fences, no extra text) with the following keys:

        - title: exhibition title
        - venue: the venue name as written on the poster (may include gallery or room names)
        - venue_poi: a simplified venue name suitable for map/POI search (e.g. museum or building name only)
        - period_text: exhibition period text
        - start_date: start date in YYYY-MM-DD
        - end_date: end date in YYYY-MM-DD
        - url: official website URL

        Use null for unknown values.
        """
        let response = try await model.generateContent(prompt, image)
        let text = response.text ?? ""
        print("🤖 AI raw response: \(text)")
        guard let json = extractFirstJSON(from: text),
              let data = json.data(using: .utf8)
        else {
            throw TextRecognitionError.aiResponseInvalid
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let payload = try decoder.decode(GeminiFlyerResponse.self, from: data)

        let titleCandidates = [payload.title?.trimmed].compactMap { $0 }.filter { !$0.isEmpty }
        let venueCandidates = [payload.venue?.trimmed].compactMap { $0 }.filter { !$0.isEmpty }
        let venuePOI = payload.venuePoi?.trimmed
        let urlCandidates = [payload.url?.trimmed].compactMap { $0 }.filter { !$0.isEmpty }

        var dateCandidates: [(Date, Date)] = []
        if let start = payload.startDate.flatMap(parseISODate),
           let end = payload.endDate.flatMap(parseISODate) {
            dateCandidates = [(start, end)]
        } else if let period = payload.periodText?.trimmed, !period.isEmpty {
            dateCandidates = DateParsingService.candidates(from: period)
        }

        let rawText = [
            payload.title,
            payload.venue,
            payload.venuePoi,
            payload.periodText,
            payload.startDate,
            payload.endDate,
            payload.url
        ]
        .compactMap { $0?.trimmed }
        .filter { !$0.isEmpty }
        .joined(separator: "\n")

        return FlyerExtractionResult(
            rawText: rawText,
            classifiedLines: [],
            titleCandidates: titleCandidates,
            venueCandidates: venueCandidates,
            venuePOI: venuePOI,
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

    private static func extractFirstJSON(from text: String) -> String? {
        guard let start = text.firstIndex(of: "{"),
              let end = text.lastIndex(of: "}")
        else {
            return nil
        }
        return String(text[start...end])
    }

    private static func parseISODate(_ text: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: text.trimmingCharacters(in: .whitespacesAndNewlines))
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

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
