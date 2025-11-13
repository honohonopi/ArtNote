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
    /// デバッグログ出力のON/OFF
    private static let debug = true
    
    // MARK: - Catalog row helpers
    
    private static let numberRegex = try! NSRegularExpression(pattern: #"^\s*([0-9]{1,3})[)\.]?\s"#)
    private static let yearHints = ["年", "世紀", "年代", "（", ")", "・", "-", "—", "〜", "~"]
    private static let materialHints = ["紙", "キャンバス", "油彩", "エッチング", "木炭", "水彩", "リトグラフ", "版", "インク", "銅版", "技法", "材質", "彩色", "ミクスト"]
    private static let collectionHints = ["美術館", "蔵", "コレクション", "Museum", "Collection"]
    
    private static func extractLeadingNumber(_ text: String) -> Int? {
        let s = text.trimmingCharacters(in: .whitespaces)
        if let m = numberRegex.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) {
            if let r = Range(m.range(at: 1), in: s) { return Int(s[r]) }
        }
        return nil
    }
    
    private static func looksLikeArtist(_ text: String) -> Bool {
        // 例: 「井上長三郎（1906・95）」のように「（生没年）」を含む / 姓名＋カッコ が強い
        let hasParenYears = text.contains("（") || text.contains("(")
        // ひらがなカタカナ漢字が主体 & “氏名っぽい単語”で終わる場合を優先
        let longish = text.count >= 2
        return longish && hasParenYears
    }
    
    private static func looksLikeMaterial(_ text: String) -> Bool {
        materialHints.contains { text.contains($0) }
    }
    
    private static func looksLikeYear(_ text: String) -> Bool {
        // 年・世紀・年代・和暦をざっくり
        yearHints.contains { text.contains($0) } || text.range(of: #"[0-9]{3,4}"#, options: .regularExpression) != nil
    }
    
    private static func looksLikeCollection(_ text: String) -> Bool {
        collectionHints.contains { text.contains($0) }
    }
    
    private static func looksLikeTitleHead(_ text: String) -> Bool {
        // 英語だけ・サイズだけ・材質だけは除外
        let s = text.trimmingCharacters(in: .whitespaces)
        if s.isEmpty { return false }
        if looksLikeYear(s) || looksLikeMaterial(s) || looksLikeCollection(s) { return false }
        // “の心の中に身を避ける”のような続き行は先頭が助詞・句読点になりがち
        let first = s.first!
        let likelyContinuationHead = "・、。)）]］」』-–—+＋".contains(first)
        return !likelyContinuationHead
    }
    
    private static func looksLikeTitleContinuation(_ text: String) -> Bool {
        // 前行の続きになりやすい：記号／助詞で始まる、あるいは英訳の続き
        let s = text.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty else { return false }
        let head = s.first!
        if "・、。)）]］」』-–—+＋".contains(head) { return true }
        // 英語の行継続（大文字始まり＋前がタイトル）のケースも拾う
        return false
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

// MARK: - Catalog OCR (List of Works) Helpers
extension TextRecognitionService {
    
    /// 目録画像から「番号 + タイトル（行頭の作品名）」候補を抽出します。
    /// - Returns: [(番号, タイトル)] を重複排除して返す
    static func extractCatalogLines(from image: UIImage) async throws -> [(number: String, title: String)] {
        let fullText = try await recognizeText(from: image)
        return extractCatalogLines(fromText: fullText)
    }
    
    static func extractCatalogLines(fromText fullText: String) -> [(number: String, title: String)] {
        // 行に分解 → 前後空白トリムのみ（ここでは削り過ぎない）
        let rawLines = fullText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        // ここでは雑音除去は extractCatalogPairsSmart 側に任せる
        let pairs = extractCatalogPairsSmart(from: rawLines)
        return pairs
    }
    
    /// 画像全体のテキストを行ごとに分類（Create ML モデル使用）
    static func classifyLines(from image: UIImage) async throws -> [ClassifiedTextFragment] {
        let fullText = try await recognizeText(from: image)
        return classifyLines(in: fullText)
    }
    
    /// 既に認識済みのテキストを行単位に分けて分類
    static func classifyLines(in fullText: String) -> [ClassifiedTextFragment] {
        let lines = fullText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        return lines.map { line in
            let label = ArtworkTextClassifier.shared.predictLabel(for: line)
            return ClassifiedTextFragment(text: line, label: label)
        }
    }
    
    
    // 末尾のメタ情報（寸法・素材・括弧注記など）をざっくり落とす（改良版）
    private static func stripTrailingMeta(from title: String) -> String {
        var t = title
        
        // よくある素材・注記・年表記を末尾限定で削る（欲張りすぎない）
        let tails = [
            #"\s*[・･]\s*(キャンバス|カンヴァス|紙|木|油彩|墨|版|インク|木炭).*$"#,
            #"\s*[（(]?(昭和|平成|令和)?[0-9０-９]{2,4}\s*年[^)]*[）)]?$"#, // 年で終わる
            #"\s*(cm|ｃｍ)$"#,
            #"\s*[（(][^）)]*[）)]$"#                              // 末尾の括弧注
        ]
        for pat in tails {
            if let rx = try? NSRegularExpression(pattern: pat, options: [.caseInsensitive]) {
                t = rx.stringByReplacingMatches(in: t, range: NSRange(t.startIndex..., in: t), withTemplate: "")
            }
        }
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// タイトルにふさわしい日本語度のざっくり判定（数字と記号ばかり、英語短文は弾く）
    private static func looksLikeJapaneseTitle(_ s: String) -> Bool {
        let scalars = s.unicodeScalars
        let jp = scalars.filter { CharacterSet(charactersIn: "一-龠ぁ-んァ-ヴー々・「」『』（）()　 ").contains($0) }.count
        let ascii = scalars.filter { $0.value < 128 }.count
        // 日本語文字が一定以上、かつ英字だけの短文ではない
        return jp >= max(2, s.count / 3) || (ascii < s.count / 2)
    }
    
    
    // 表頭・注意書き・見出し・寸法などを弾く（強化版）
    private static func isHeaderOrMeta(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return true }
        
        // 表頭・注意書き類
        let headerKeywords = [
            "作品名","制作年","技法","技法等","所蔵","出品リスト","※","このリスト","並びは","変更",
            "No","番号","LIST","EXHIBITION","CATALOG","INDEX",
            "会期","会場","主催","後援","協賛","アクセス","休館","観覧料","開館","Museum","of Art"
        ]
        if headerKeywords.contains(where: { t.localizedCaseInsensitiveContains($0) }) { return true }
        
        // 寸法（xx.x × yy.y）
        if t.range(of: #"[0-9０-９]+(\.[0-9０-９]+)?\s*[×xX]\s*[0-9０-９]+(\.[0-9０-９]+)?\s*(cm|ｃｍ)?"#, options: .regularExpression) != nil {
            return true
        }
        
        // 英字のみかつ短い見出し（ノイズ）
        let onlyASCII = t.unicodeScalars.allSatisfy { $0.value < 128 }
        if onlyASCII && t.split(separator: " ").count <= 5 { return true }
        
        return false
    }
    
    // 人名＋（生没年/生年など）っぽい行
    private static func isArtistLine(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        // 「（XXXX・YYYY）」や「（XXXX-YYYY）」等の年情報
        if t.range(of: #"\([0-9０-９]{3,4}[^)]*\)"#, options: .regularExpression) != nil {
            // 先頭側が日本語の人名っぽいか（漢字/かな/中黒・スペース）
            let head = t.split(separator: "（").first.map(String.init) ?? t
            let jpCount = head.unicodeScalars.filter {
                CharacterSet(charactersIn: "一-龠ぁ-んァ-ヴー々・　 ").contains($0)
            }.count
            if jpCount >= max(2, head.count / 2) { return true }
        }
        return false
    }
    
    // 先頭の「人名＋（年）」を落とす（タイトルだけ残す）
    private static func stripLeadingPersonAndYears(_ s: String) -> String {
        var t = s
        if let close = t.firstIndex(of: "）") {
            let before = t[..<t.index(after: close)]
            let after  = t[t.index(after: close)...].trimmingCharacters(in: .whitespaces)
            if before.range(of: #"[0-9０-９]{3,4}"#, options: .regularExpression) != nil, !after.isEmpty {
                t = String(after)
            }
        }
        return t
    }
    
    // 全角数字を半角に
    private static func normalizeDigits(_ s: String) -> String {
        s.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? s
    }
    
    // 賢い抽出本体（改良版）
    private static func extractCatalogPairsSmart(from lines: [String]) -> [(number: String, title: String)] {
        var pairs: [(String, String)] = []
        var lastArtistIndex: Int? = nil
        
        // 行頭番号（全角/半角、句読点・記号ゆるめ）
        let numberedRegex = try! NSRegularExpression(
            pattern: #"^\s*([0-9０-９]{1,3})\s*[)\.．:、】]?\s+(.+)$"#
        )
        // 先頭に番号が無くても、直前/直後行に「No.」「番号」等があるときの緩和用ウィンドウ
        let window = 2
        
        for (idx, raw) in lines.enumerated() {
            var line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty || isHeaderOrMeta(line) { continue }
            
            // (0) まずは分類（Create ML）
            let predicted = ArtworkTextClassifier.shared.predictLabel(for: line)
            
            // (1) 行頭番号＋タイトルの直取り
            if let m = numberedRegex.firstMatch(in: line, options: [], range: NSRange(location: 0, length: (line as NSString).length)),
               m.numberOfRanges >= 3
            {
                let ns = line as NSString
                var noRaw   = ns.substring(with: m.range(at: 1))
                var title   = ns.substring(with: m.range(at: 2))
                
                noRaw = normalizeDigits(noRaw)
                
                // 西暦の誤認を排除（0/300超/1000〜2100は弾く）
                if let n = Int(noRaw), !(n <= 0 || n > 300 || (1000...2100).contains(n)) {
                    title = stripLeadingPersonAndYears(title)
                    title = stripTrailingMeta(from: title)
                    
                    // 分類器で最終確認：タイトルでなければ採用しない
                    if ArtworkTextClassifier.shared.predictLabel(for: title) == .title,
                       title.count >= 2,
                       looksLikeJapaneseTitle(title)
                    {
                        pairs.append((noRaw, title))
                        lastArtistIndex = nil
                        if debug { print("[pair-num]\t#\(noRaw): \(title)") }
                        continue
                    }
                }
            }
            
            // (2) 作家行を覚えて、次行をタイトル候補として見る
            if isArtistLine(line) {
                lastArtistIndex = idx
                if debug { print("[artist]\t@\(idx): \(line)") }
                continue
            }
            
            if let a = lastArtistIndex, idx == a + 1 {
                var title = stripLeadingPersonAndYears(line)
                title = stripTrailingMeta(from: title)
                if ArtworkTextClassifier.shared.predictLabel(for: title) == .title,
                   title.count >= 2,
                   looksLikeJapaneseTitle(title)
                {
                    // 番号は前後から推定（作家行 or 現行）
                    var no = "?"
                    if let numR = lines[a].range(of: #"[0-9０-９]{1,3}"#, options: .regularExpression) {
                        no = normalizeDigits(String(lines[a][numR]))
                    } else if let numR2 = line.range(of: #"[0-9０-９]{1,3}"#, options: .regularExpression) {
                        no = normalizeDigits(String(line[numR2]))
                    }
                    pairs.append((no, title))
                    lastArtistIndex = nil
                    if debug { print("[pair-a+1]\t#\(no): \(title)") }
                    continue
                }
            }
            
            // (2.5) 近傍2行内に番号ヒント（「No」「番号」「#」＋数字）がある場合に補完
            if predicted == .title {
                var title = stripLeadingPersonAndYears(line)
                title = stripTrailingMeta(from: title)
                if title.count >= 2, looksLikeJapaneseTitle(title) {
                    var hintedNo: String? = nil
                    let hintRegex = try! NSRegularExpression(pattern: #"(?:No\.?|番号|#)\s*([0-9０-９]{1,3})"#)
                    let start = max(0, idx - window)
                    let end   = min(lines.count - 1, idx + window)
                    outer: for j in start...end where j != idx {
                        let s = lines[j]
                        let ns = s as NSString
                        if let m = hintRegex.firstMatch(in: s, options: [], range: NSRange(location: 0, length: ns.length)),
                           m.numberOfRanges >= 2 {
                            let raw = ns.substring(with: m.range(at: 1))
                            let nn = normalizeDigits(raw)
                            if let nInt = Int(nn), nInt > 0, nInt <= 300 {
                                hintedNo = nn
                                break outer
                            }
                        }
                    }
                    if let nn = hintedNo {
                        pairs.append((nn, title))
                        if debug { print("[pair-hint]\t#\(nn): \(title)") }
                        continue
                    }
                }
            }
            
            // (3) 直番号も作家の手掛かりもないが、分類が title なら暫定採用（番号は?）
            if predicted == .title {
                var title = stripLeadingPersonAndYears(line)
                title = stripTrailingMeta(from: title)
                if title.count >= 2, looksLikeJapaneseTitle(title) {
                    pairs.append(("?", title))
                    lastArtistIndex = nil
                    if debug { print("[pair-?]\t#?: \(title)") }
                }
            }
        }
        
        // ユニーク化（番号が?のものはタイトルでユニーク、番号があるものは番号でユニーク）
        var seenKey = Set<String>()
        var uniq: [(String, String)] = []
        for (no, title) in pairs {
            let key = (no == "?") ? "?:\(title)" : "no:\(no)"
            if seenKey.insert(key).inserted {
                uniq.append((no, title))
            }
        }
        
        // デバッグ出力
        if debug {
            print("=== extracted catalog pairs ===")
            for p in uniq { print("#\(p.0): \(p.1)") }
        }
        return uniq
    }
}

import Vision
import CoreImage

struct CatalogRow: Identifiable {
    let id = UUID()
    var number: String?
    var title: String?
    var artist: String?
    var year: String?
    var material: String?
    var collection: String?
    var size: String?
    // 行の生テキスト（デバッグ用）
    var raw: String
}

extension TextRecognitionService {
    
    /// 表画像から「1作品=1行」に再構成
    func recognizeCatalogTable(from uiImage: UIImage) async throws -> [CatalogRow] {
        guard let cg = uiImage.cgImage else { return [] }
        
        let req = VNRecognizeTextRequest()
        req.recognitionLevel = .accurate
        req.usesLanguageCorrection = true
        req.recognitionLanguages = ["ja", "en"]
        
        let handler = VNImageRequestHandler(cgImage: cg, options: [:])
        try handler.perform([req])
        
        guard let obs = req.results as? [VNRecognizedTextObservation], !obs.isEmpty else { return [] }
        
        // 1) 行クラスタリング（Y中心でバケツ分け）
        let rows = clusterIntoRows(observations: obs, toleranceY: 0.015)
        
        // 2) ヘッダで列境界を推定
        let headerCandidate = rows.prefix(3).flatMap { $0 } // 上部数行を候補に
        let columnEdges = estimateColumnEdges(from: headerCandidate)
        
        // 3) 行→列の再構成
        var results: [CatalogRow] = []
        for line in rows {
            let sorted = line.sorted { $0.boundingBox.minX < $1.boundingBox.minX }
            let pieces = sorted.compactMap { $0.topCandidates(1).first?.string.trimmingCharacters(in: .whitespacesAndNewlines) }
            let raw = pieces.joined(separator: " ")
            
            // 列レンジに割当
            let assigned = assignToColumns(line: sorted, edges: columnEdges)
            
            var row = CatalogRow(number: nil,
                                 title: assigned["title"],
                                 artist: assigned["artist"],
                                 year: assigned["year"],
                                 material: assigned["material"],
                                 collection: assigned["collection"],
                                 size: assigned["size"],
                                 raw: raw)
            
            // 先頭の番号推定
            if row.number == nil {
                row.number = extractNumber(from: raw)
            }
            // 年など軽い正規化
            row.year = normalizeYear(row.year)
            
            // ノイズ行の除外条件（タイトルや作者が全く取れない等）
            if (row.title?.isEmpty ?? true) && (row.artist?.isEmpty ?? true) { continue }
            
            results.append(row)
        }
        return results
    }
    
    private func clusterIntoRows(observations: [VNRecognizedTextObservation], toleranceY: CGFloat) -> [[VNRecognizedTextObservation]] {
        // toleranceY: 画像の正規化座標（0〜1）
        var buckets: [[VNRecognizedTextObservation]] = []
        let sorted = observations.sorted { $0.boundingBox.midY > $1.boundingBox.midY } // 上→下
        for ob in sorted {
            let y = ob.boundingBox.midY
            if let idx = buckets.firstIndex(where: { group in
                guard let gy = group.first?.boundingBox.midY else { return false }
                return abs(gy - y) < toleranceY
            }) {
                buckets[idx].append(ob)
            } else {
                buckets.append([ob])
            }
        }
        return buckets
    }
    
    private func estimateColumnEdges(from observations: [VNRecognizedTextObservation]) -> [String: ClosedRange<CGFloat>] {
        // 見出し語に反応したX位置からレンジを作る
        // ざっくりの初期値（左→右）
        var edges: [String: ClosedRange<CGFloat>] = [
            "number"    : 0.00...0.08,
            "artist"    : 0.08...0.28,
            "title"     : 0.28...0.62,
            "year"      : 0.62...0.74,
            "material"  : 0.74...0.88,
            "collection": 0.88...1.00,
            "size"      : 0.88...1.00
        ]
        
        func bump(for key: String, at x: CGFloat) {
            // シンプルに“その列の中心”をxに寄せる
            let w: CGFloat = 0.12
            edges[key] = max(0, x - w/2)...min(1, x + w/2)
        }
        
        for ob in observations {
            guard let s = ob.topCandidates(1).first?.string else { continue }
            let x = ob.boundingBox.midX
            if s.contains("作者") || s.localizedCaseInsensitiveContains("Artist") { bump(for: "artist", at: x) }
            if s.contains("作品") || s.localizedCaseInsensitiveContains("Title") { bump(for: "title", at: x) }
            if s.contains("制作年") || s.localizedCaseInsensitiveContains("Date") || s.contains("年") { bump(for: "year", at: x) }
            if s.contains("素材") || s.contains("技法") || s.localizedCaseInsensitiveContains("Material") { bump(for: "material", at: x) }
            if s.contains("所蔵") || s.localizedCaseInsensitiveContains("Collection") { bump(for: "collection", at: x) }
            if s.contains("サイズ") || s.localizedCaseInsensitiveContains("Size") { bump(for: "size", at: x) }
            if s.hasPrefix("No") { bump(for: "number", at: x) }
        }
        return edges
    }
    
    private func assignToColumns(line: [VNRecognizedTextObservation], edges: [String: ClosedRange<CGFloat>]) -> [String: String] {
        var cols: [String: [String]] = [:]
        for ob in line {
            guard let t = ob.topCandidates(1).first else { continue }
            let s = t.string.trimmingCharacters(in: .whitespacesAndNewlines)
            let x = ob.boundingBox.midX
            
            // どの列レンジに入るか
            let key = edges.first(where: { $0.value.contains(x) })?.key ?? "title"
            // 低信頼文字は弾く
            if t.confidence < 0.40 { continue }
            cols[key, default: []].append(s)
        }
        // つなぐ
        var out: [String: String] = [:]
        for (k, arr) in cols {
            out[k] = arr.joined(separator: " ")
        }
        return out
    }
    
    private func extractNumber(from raw: String) -> String? {
        if let m = raw.range(of: #"^\s*\d{1,3}"#, options: .regularExpression) {
            return String(raw[m]).trimmingCharacters(in: .whitespaces)
        }
        return nil
    }
    
    private func normalizeYear(_ s: String?) -> String? {
        guard var s = s else { return nil }
        s = s.replacingOccurrences(of: "（", with: "(")
            .replacingOccurrences(of: "）", with: ")")
            .replacingOccurrences(of: "・", with: "・")
        return s
    }
    
    /// 行テキスト + 予測ラベル（Create ML）
    /// 既に同等の型がある場合は、こちらの typealias のみ残してください。
    public struct ClassifiedTextFragment: Identifiable {
        public let id = UUID()
        public let text: String
        public let label: ArtworkFieldLabel
    }
    
    /// TextRecognitionService.mergeArtistAndTitles の入力は
    /// 画面側で扱っている ClassifiedTextFragment と同義にします。
    public typealias CatalogItem = ClassifiedTextFragment
    
    /// 1作品=1行 に束ねた結果
    public struct MergedPair: Identifiable, Equatable {
        public let id = UUID()
        public var number: Int?      // 例: 14, 15, …（不明なら nil）
        public var artist: String    // 例: "井上長三郎"（不明なら "?"）
        public var title: String     // 例: "キリスト" 等
    }
    /// OCRで拾った「番号/作家/タイトル断片」を、1作品=1行に束ねる。
    public func mergeArtistAndTitles(from items: [CatalogItem]) -> [MergedPair] {
        struct Building {
            var number: Int?
            var artist: String?
            var title: String = ""
        }
        var results: [MergedPair] = []
        var currentNumber: Int? = nil
        var currentArtist: String? = nil
        var building: Building? = nil
        
        func flush() {
            guard let b = building else { return }
            let a = b.artist ?? currentArtist ?? "?"
            let t = b.title.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            results.append(MergedPair(number: b.number ?? currentNumber,
                                      artist: a,
                                      title: t.isEmpty ? "?" : t))
            building = nil
        }
        
        for it in items {
            let t = it.text.trimmingCharacters(in: CharacterSet.whitespaces)
            
            // 1) 番号行
            if let n = TextRecognitionService.extractLeadingNumber(t) {
                // 直前のタイトルが組み立て途中なら確定してから番号更新
                flush()
                currentNumber = n
                continue
            }
            
            // 2) 作家行
            if TextRecognitionService.looksLikeArtist(t) {
                // 直前のタイトルが組み立て途中なら確定してから作家更新
                flush()
                // 行頭の通し番号などを除去
                currentArtist = t.replacingOccurrences(of: #"^\d+\s*"#,
                                                       with: "",
                                                       options: NSString.CompareOptions.regularExpression,
                                                       range: nil)
                continue
            }
            
            // 3) 年・材質・所蔵はスキップ（タイトル抽出に集中）
            if TextRecognitionService.looksLikeYear(t)
                || TextRecognitionService.looksLikeMaterial(t)
                || TextRecognitionService.looksLikeCollection(t) {
                continue
            }
            
            // 4) タイトル頭
            if TextRecognitionService.looksLikeTitleHead(t) {
                flush() // 直前のタイトルがあれば確定
                building = Building(number: currentNumber, artist: currentArtist, title: t)
                continue
            }
            
            // 5) タイトル続き（改行折返し）
            if TextRecognitionService.looksLikeTitleContinuation(t) {
                if var b = building {
                    b.title += t.hasPrefix(" ") ? t : " " + t
                    building = b
                } else if !t.isEmpty {
                    // タイトル途中扱いで新規開始（番号/作家は現状を継承）
                    building = Building(number: currentNumber, artist: currentArtist, title: t)
                }
                continue
            }
            
            // 6) その他は捨てる
        }
        
        // 最終フラッシュ
        flush()
        
        // 同一番号・同一作家でタイトルが複数並んだ場合は結合（箇条書き）
        var collapsed: [MergedPair] = []
        var bucket: [MergedPair] = []
        
        func pushBucket() {
            guard !bucket.isEmpty else { return }
            if bucket.count == 1 {
                collapsed.append(bucket[0])
            } else {
                let num = bucket.first!.number
                let artist = bucket.first!.artist
                let joined = bucket.map { "・" + $0.title }.joined(separator: "\n")
                collapsed.append(MergedPair(number: num, artist: artist, title: joined))
            }
            bucket.removeAll()
        }
        
        for r in results {
            if let last = bucket.last, last.number == r.number, last.artist == r.artist {
                bucket.append(r)
            } else {
                pushBucket()
                bucket.append(r)
            }
        }
        pushBucket()
        
        return collapsed
    }
}
