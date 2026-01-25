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

#if false
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
        let schedule: ScheduleExtraction?
        let dateCandidates: [(Date, Date)]
        let urlCandidates: [String]
    }

    struct ScheduleExtraction {
        let openTime: String?
        let closeTime: String?
        let lastEntryTime: String?
        let closedWeekdays: [Weekday]
        let holidayHandling: HolidayHandling?
        let closedDates: [Date]
        let openDates: [Date]
        let specialOpenings: [SpecialOpening]
    }

    private struct GeminiFlyerResponse: Decodable {
        let title: String?
        let venue: String?
        let venuePoi: String?
        let periodText: String?
        let startDate: String?
        let endDate: String?
        let regularSchedule: GeminiRegularSchedule?
        let exceptions: GeminiExceptions?
        let url: String?
    }

    private struct GeminiRegularSchedule: Decodable {
        let openTime: String?
        let closeTime: String?
        let lastEntryTime: String?
        let closedWeekdays: [String]?
        let holidayHandling: String?
    }

    private struct GeminiExceptions: Decodable {
        let closedDates: [String]?
        let openDates: [String]?
        let specialOpenings: [GeminiSpecialOpening]?
    }

    private struct GeminiSpecialOpening: Decodable {
        let date: String?
        let openTime: String?
        let closeTime: String?
        let lastEntryTime: String?
        let note: String?
    }

    private struct GeminiExtraInfoResponse: Decodable {
        let admission: GeminiAdmission?
        let reservation: GeminiReservation?
    }

    private struct GeminiAdmission: Decodable {
        let fees: [GeminiAdmissionFee]?
    }

    private struct GeminiReservation: Decodable {
        let required: Bool?
        let note: String?
    }

    private struct GeminiAdmissionFee: Decodable {
        let category: String?
        let label: String?
        let priceYen: Int?
        let note: String?
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
            if DateExtractor.looksLikePeriodText(line.text) {
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

        // conf 上位から順に DateExtractor へ投げ、最初にパースできた候補群を採用
        var dateCandidates: [(Date, Date)] = []
        if !periodCore.isEmpty {
            // 最大 6 行まで試す（必要なら調整）
            for cand in periodCore.prefix(6) {
                let cands = DateExtractor.candidates(from: cand.text)
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
            dateCandidates = DateExtractor.candidates(from: periodSource)
        }
        // === ここまで period 強化 ===
        
        // ③ ラベル付き行が空なら、従来どおり全文を使って解析するフォールバック
        let titleSource  = titleLines.isEmpty  ? raw : titleLines.joined(separator: "\n")
        let venueSource  = venueLines.isEmpty  ? raw : venueLines.joined(separator: "\n")
        let urlSource    = urlLines.isEmpty    ? raw : urlLines.joined(separator: "\n")
        
        // ④ 既存のヘルパー群をそのまま活かす
        let titleCandidates = TitleExtractor.candidates(from: titleSource)
        let venueCandidates = VenueExtractor.candidates(from: venueSource)
        let urlCandidates   = extractURLs(from: urlSource)
        
        return FlyerExtractionResult(
            rawText: raw,
            classifiedLines: lines,
            titleCandidates: titleCandidates,
            venueCandidates: venueCandidates,
            venuePOI: nil,
            schedule: nil,
            dateCandidates: dateCandidates,
            urlCandidates: urlCandidates
        )
    }

    // MARK: - Gemini
    /// Gemini を使ったポスター情報抽出（JSON で返す）
    static func extractFlyerFieldsWithAI(from image: UIImage) async throws -> FlyerExtractionResult {
        let model = GenerativeModel(name: "gemini-2.5-flash-lite", apiKey: APIKey.default)
        let prompt = """
        You are extracting factual exhibition information from a Japanese exhibition poster image.

        Respond ONLY in valid JSON.
        Do NOT include explanations, markdown, or extra text.

        --------------------------------
        GENERAL RULES
        --------------------------------
        - Extract ONLY factual information explicitly written on the poster.
        - Do NOT infer, interpret, or normalize meanings beyond the instructions below.
        - Do NOT include exhibition descriptions, artist explanations, curatorial texts, or event descriptions.
        - If information is not clearly stated, use null or empty arrays.
        - Dates must be converted to YYYY-MM-DD.
        - Times must be converted to 24-hour HH:mm format.

        --------------------------------
        OUTPUT FORMAT
        --------------------------------

        {
          "title": string,
          "venue": string,
          "venue_poi": string,

          "period": {
            "start_date": "YYYY-MM-DD",
            "end_date": "YYYY-MM-DD",
            "period_text": string
          },

          "regular_schedule": {
            "open_time": "HH:mm",
            "close_time": "HH:mm",
            "last_entry_time": "HH:mm" | null,
            "closed_weekdays": [
              "monday" | "tuesday" | "wednesday" | "thursday" | "friday" | "saturday" | "sunday"
            ],
            "holiday_handling": "NONE" | "OPEN_ON_HOLIDAY" | "OPEN_ON_HOLIDAY_CLOSE_NEXT_WEEKDAY"
          },

          "exceptions": {
            "closed_dates": ["YYYY-MM-DD"],
            "open_dates": ["YYYY-MM-DD"],
            "special_openings": [
              {
                "date": "YYYY-MM-DD"
                      | "EVERY_MONDAY" | "EVERY_TUESDAY" | "EVERY_WEDNESDAY"
                      | "EVERY_THURSDAY" | "EVERY_FRIDAY"
                      | "EVERY_SATURDAY" | "EVERY_SUNDAY",
                "open_time": "HH:mm",
                "close_time": "HH:mm",
                "last_entry_time": "HH:mm" | null,
                "note": string | null
              }
            ]
          },

          "admission": {
            "is_free": boolean,
            "fees": [
              {
                "category":
                  "adult"
                  | "university_student"
                  | "high_school_student"
                  | "junior_high_student"
                  | "elementary_student"
                  | "preschool"
                  | "senior"
                  | "free"
                  | "other",
                "label": string,
                "price_yen": number | null,
                "note": string | null
              }
            ]
          },

          "reservation": {
            "required": boolean,
            "note": string | null
          },

          "url": string | null
        }

        --------------------------------
        DETAILED INSTRUCTIONS
        --------------------------------

        ### period
        - Extract the exhibition period exactly as written.
        - Convert to start_date and end_date when possible.

        ### regular_schedule
        - Use this ONLY for the default opening rule.
        - If multiple default rules exist (e.g. Fridays only), use special_openings instead.
        - If no closed weekday is specified, return an empty array.
        - If holiday handling is not clearly stated, set holiday_handling to "NONE".

        ### exceptions
        - Use ONLY when explicitly stated.
        - closed_dates: specific dates when the exhibition is closed.
        - open_dates: specific dates when the exhibition is open despite normal closure.
        - special_openings: only when opening hours differ from the regular schedule.

        ### admission (IMPORTANT)
        - Extract ONLY admission fee information.
        - Set is_free to true ONLY if the exhibition is explicitly stated as free.
        - For each fee:
          - category must be chosen from the predefined enum.
          - label must preserve the original wording on the poster
            (e.g. "中高生", "小学生以下", "高校生・大学生").
        - If a category covers multiple age groups (e.g. "中高生"):
          - Choose the closest representative category
            (e.g. "high_school_student").
        - If the fee is free, set price_yen to 0 and explain briefly in note if needed.
        - price_yen = null MUST NEVER mean free.
        - Do NOT merge or split categories beyond what is written.
        - Do NOT interpret user attributes.

        ### reservation
        - Set required to true ONLY if advance reservation is explicitly required.
        - If reservation is partial or conditional, set required to true and explain briefly in note.

        --------------------------------
        IMPORTANT PROHIBITIONS
        --------------------------------
        - Do NOT infer missing prices or age rules.
        - Do NOT invent categories.
        - Do NOT normalize categories into broader concepts (e.g. do NOT convert to "student").
        - Do NOT output explanations.

        If information cannot be confidently extracted, use null or empty arrays.

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
        let schedule = buildSchedule(from: payload)

        var dateCandidates: [(Date, Date)] = []
        if let start = payload.startDate.flatMap(parseISODate),
           let end = payload.endDate.flatMap(parseISODate) {
            dateCandidates = [(start, end)]
        } else if let period = payload.periodText?.trimmed, !period.isEmpty {
            dateCandidates = DateExtractor.candidates(from: period)
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
            schedule: schedule,
            dateCandidates: dateCandidates,
            urlCandidates: urlCandidates
        )
    }

    // MARK: - Gemini (Extra Info)
    static func extractExtraInfoWithAI(from image: UIImage) async -> (fees: [AdmissionFeeRule], reservationRequired: Bool?)? {
        let model = GenerativeModel(name: "gemini-2.5-flash-lite", apiKey: APIKey.default)
        let prompt = """
        You are extracting factual ticket/admission and reservation information from a Japanese exhibition poster image.

        Respond ONLY in valid JSON.
        Do NOT include explanations, markdown, or extra text.

        --------------------------------
        GENERAL RULES
        --------------------------------
        - Extract ONLY factual information explicitly written on the poster.
        - Do NOT infer or compute missing numeric values.
        - If information is not clearly stated, use null or empty arrays.
        - Prices are in Japanese Yen.

        --------------------------------
        OUTPUT FORMAT
        --------------------------------
        {
          "admission": {
            "is_free": boolean,
            "fees": [
              {
                "category": "adult" | "university_student" | "vocational_student" | "high_school_student" | "junior_high_student" | "elementary_student" | "preschool" | "senior" | "free" | "other",
                "label": string,
                "price_yen": number | null,
                "note": string | null
              }
            ]
          },
          "reservation": {
            "required": boolean,
            "note": string | null
          }
        }

        --------------------------------
        DETAILED INSTRUCTIONS
        --------------------------------
        ### admission.is_free
        - Set true ONLY if the poster clearly states the exhibition is free for everyone (e.g., "入場無料", "観覧無料").
        - If free is conditional (e.g., "18歳以下無料", "障がい者手帳...無料"), set is_free to false.

        ### admission.fees
        - Each entry represents one line/segment of fee information on the poster.
        - label: keep the original wording as written (e.g., "一般", "高校生・大学生", "18歳以下").
        - price_yen:
          - If it is explicitly FREE, set price_yen = 0.
          - If the poster does NOT provide a clear numeric price, set price_yen = null.
          - If it is a discount without a numeric price (e.g., "半額", "2割引"), set price_yen = null AND explain in note that it is discounted (NOT free).
        - Parentheses group fees:
          - If written like "1500円（1300円）" and the poster also states the parentheses represent group pricing (e.g., "20名以上団体"),
            output ONE fee entry with price_yen = 1500 and write the group info in note (e.g., "団体(20名以上): 1300円").
          - Do NOT create a separate fee entry solely for the parentheses group price.
        - If a line only describes group/discount policy (e.g., "20名以上の団体料金", "2回目ご来館時 半額"):
          - Do NOT create a standalone fee row for it.
          - Attach it as note to the closest main fee line instead.
        - Conditional free:
          - Use category = "other" (or the closest category if clearly applicable).
          - Set price_yen = 0 only if the poster clearly states it is free for that condition, and write the condition in note.
        - IMPORTANT: price_yen = null MUST NEVER mean free.

        ### reservation
        - required: true ONLY if advance reservation is explicitly required ("事前予約制", "日時指定予約必須", etc.).
        - If reservation is partial/conditional, set required = true and explain in note.

        --------------------------------
        IMPORTANT PROHIBITIONS
        --------------------------------
        - Do NOT compute numeric discounted prices (e.g., do NOT convert "半額" to 750).
        - Do NOT invent missing admission information.
        """
        do {
            let response = try await model.generateContent(prompt, image)
            let text = response.text ?? ""
            guard let json = extractFirstJSON(from: text),
                  let data = json.data(using: .utf8)
            else {
                return nil
            }
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let payload = try decoder.decode(GeminiExtraInfoResponse.self, from: data)
            guard let fees = payload.admission?.fees else {
                return nil
            }
            let mapped = mapAdmissionFees(fees)
            return (fees: mapped, reservationRequired: payload.reservation?.required)
        } catch {
            return nil
        }
    }

    private static func mapAdmissionFees(_ fees: [GeminiAdmissionFee]) -> [AdmissionFeeRule] {
        fees.compactMap { fee in
            let labelFromPayload = fee.label?.trimmed
            let rawLabel = (labelFromPayload?.isEmpty == false ? labelFromPayload! : (defaultAdmissionLabel(for: fee.category) ?? "不明"))
            var note = fee.note?.trimmed
            var price = fee.priceYen
            let category = fee.category?.trimmed.lowercased()

            // 1) category=="free" は必ず free を意味するので 0 に寄せる（モデルがnullで返しても安全に）
            if category == "free" {
                price = 0
            }

            // 2) 「無料」と明記されてるのに price が null の場合は 0 に補正（安全寄り）
            if price == nil {
                let t = rawLabel + " " + (note ?? "")
                if t.contains("無料") {
                    price = 0
                }
            }
            // 3) price==0 なのに「無料」明記が無いなら怪しいので nil に戻す（誤無料表示防止）
            if price == 0 {
                let t = rawLabel + " " + (note ?? "")
                if !t.contains("無料") && category != "free" {
                    price = nil
                    let warn = "※0円と断定できないため未取得扱い"
                    note = [note, warn].compactMap { $0?.isEmpty == false ? $0 : nil }.joined(separator: " / ")
                }
            }
            return AdmissionFeeRule(
                rawLabel: rawLabel,
                priceYen: price,                       // free=0 / unknown&discount=null
                note: note?.isEmpty == false ? note : nil,
                targets: []                            // targets は後段（ルール/ユーザー編集）で付与
            )
        }
    }

    private static func defaultAdmissionLabel(for category: String?) -> String? {
        switch category {
        case "adult": return "一般"
        case "university_student": return "大学生"
        case "vocational_student": return "専門学生"
        case "high_school_student": return "高校生"
        case "junior_high_student": return "中学生"
        case "elementary_student": return "小学生"
        case "preschool": return "未就学児"
        case "senior": return "シニア"
        case "free": return "無料"
        case "other": return "その他"
        default: return nil
        }
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

    private static func buildSchedule(from payload: GeminiFlyerResponse) -> ScheduleExtraction? {
        guard let regular = payload.regularSchedule else { return nil }
        let openTime = regular.openTime?.trimmed
        let closeTime = regular.closeTime?.trimmed
        let lastEntryTime = regular.lastEntryTime?.trimmed
        let closedWeekdays = (regular.closedWeekdays ?? [])
            .compactMap { Weekday(rawValue: $0.lowercased()) }
        let holidayHandling = parseHolidayHandling(regular.holidayHandling) ?? .none

        let closedDates = (payload.exceptions?.closedDates ?? [])
            .compactMap { parseISODate($0) }
        let openDates = (payload.exceptions?.openDates ?? [])
            .compactMap { parseISODate($0) }
        let specialOpenings = (payload.exceptions?.specialOpenings ?? [])
            .compactMap { entry -> SpecialOpening? in
                guard let dateStr = entry.date?.trimmed, !dateStr.isEmpty else { return nil }
                if let weekday = parseWeekdayRule(dateStr) {
                    return SpecialOpening(
                        rule: .weekday(weekday),
                        openTime: entry.openTime ?? "",
                        closeTime: entry.closeTime ?? "",
                        lastEntryTime: entry.lastEntryTime,
                        note: entry.note
                    )
                }
                guard let date = parseISODate(dateStr) else { return nil }
                return SpecialOpening(
                    rule: .date(date),
                    openTime: entry.openTime ?? "",
                    closeTime: entry.closeTime ?? "",
                    lastEntryTime: entry.lastEntryTime,
                    note: entry.note
                )
            }

        if openTime == nil,
           closeTime == nil,
           lastEntryTime == nil,
           closedWeekdays.isEmpty,
           holidayHandling == nil,
           closedDates.isEmpty,
           openDates.isEmpty,
           specialOpenings.isEmpty {
            return nil
        }

        return ScheduleExtraction(
            openTime: openTime,
            closeTime: closeTime,
            lastEntryTime: lastEntryTime,
            closedWeekdays: closedWeekdays,
            holidayHandling: holidayHandling,
            closedDates: closedDates,
            openDates: openDates,
            specialOpenings: specialOpenings
        )
    }

    private static func parseHolidayHandling(_ value: String?) -> HolidayHandling? {
        guard let raw = value?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
              !raw.isEmpty
        else { return nil }
        switch raw {
        case "NONE": return .none
        case "OPEN_ON_HOLIDAY": return .openOnHoliday
        case "OPEN_ON_HOLIDAY_CLOSE_NEXT_WEEKDAY": return .openOnHolidayCloseNextWeekday
        default: return nil
        }
    }

    private static func parseWeekdayRule(_ value: String) -> Weekday? {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if normalized.hasPrefix("EVERY_") {
            let raw = normalized.replacingOccurrences(of: "EVERY_", with: "")
            return Weekday(rawValue: raw.lowercased())
        }
        return nil
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

#endif
