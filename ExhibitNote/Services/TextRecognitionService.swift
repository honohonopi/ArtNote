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

// MARK: - Catalog OCR (List of Works) Helpers
extension TextRecognitionService {

    /// 目録画像から「番号 + タイトル（行頭の作品名）」候補を抽出します。
    /// - Returns: [(番号, タイトル)] を重複排除して返す
    static func extractCatalogLines(from image: UIImage) async throws -> [(number: String, title: String)] {
        let fullText = try await recognizeText(from: image)
        return extractCatalogLines(fromText: fullText)
    }

    /// 認識済みテキストから行ごとの番号+タイトル候補を抽出
    /// - Important:
    ///   日本語の目録でよく出るパターンを複数拾います:
    ///   1) `^\d+\s+タイトル`
    ///   2) `^\d+[.)、:]?\s*タイトル`
    ///   3) `No.12 タイトル` / `Cat. 12 タイトル`
    static func extractCatalogLines(fromText fullText: String) -> [(number: String, title: String)] {
        // 行単位に分割（空行除去）
        let lines = fullText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        // よくある3種のパターン
        // 例: "12 ひまわり", "12) タイトル", "12. タイトル", "No.12 タイトル", "Cat. 7 作品名"
        let patterns: [String] = [
            #"^\s*([0-9]{1,4})\s+(.+)$"#,
            #"^\s*([0-9]{1,4})[)\.\:、]?\s*(.+)$"#,
            #"^\s*(?:No\.?|Cat\.?)\s*([0-9]{1,4})\s+(.+)$"#
        ]
        let regexes = patterns.compactMap { try? NSRegularExpression(pattern: $0) }

        var pairs: [(String, String)] = []

        for line in lines {
            // ノイズが多い行は早期スキップ（英数字だけや寸法・素材の行などを簡易に弾く）
            let lower = line.lowercased()
            if lower.contains("cm") || lower.contains("mm") || lower.contains("紙") || lower.contains("oil") {
                // 但し完全には弾かず、番号+タイトルが取れるなら採用したいので continue せずに正規表現にはかける
            }

            for rx in regexes {
                if let m = rx.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
                   m.numberOfRanges >= 3,
                   let rNo = Range(m.range(at: 1), in: line),
                   let rTi = Range(m.range(at: 2), in: line) {

                    let no = String(line[rNo]).trimmingCharacters(in: .whitespacesAndNewlines)
                    var title = String(line[rTi]).trimmingCharacters(in: .whitespacesAndNewlines)

                    // タイトル末尾にある「作者名」「素材」「年代」っぽい尾部を軽くカット（ゆるめ）
                    title = stripTrailingMeta(from: title)

                    // 取りすぎ防止（短すぎは除外）
                    if title.count >= 2 {
                        pairs.append((no, title))
                    }
                    break
                }
            }
        }

        // 番号でユニーク化（同番号で複数拾ったら最初のものを採用）
        var seen = Set<String>()
        var uniq: [(String, String)] = []
        for p in pairs {
            if seen.insert(p.0).inserted {
                uniq.append(p)
            }
        }
        return uniq
    }

    /// 末尾のメタ情報（寸法・素材・括弧注記など）をざっくり落とす
    private static func stripTrailingMeta(from title: String) -> String {
        var t = title

        // よくある区切り記号以降を削る（例: "タイトル　油彩・キャンバス 1908年"）
        // ※ 貪欲に削りすぎないよう末尾側に限定した軽いルール
        let tails = [
            #"(\s*[・･]\s*キャンバス.*)$"#,
            #"(\s*[・･]\s*紙.*)$"#,
            #"(\s*[・･]\s*木.*)$"#,
            #"(\s*[・･]\s*油彩.*)$"#,
            #"(\s*[・･]\s*墨.*)$"#,
            #"(\s*\(?[0-9]{3,4}\s*年[^\)]*\)?$)"#,   // 年代で終わる
            #"(\s*cm$)"#,
            #"(\s*\([^\)]*\)$)"#                     // 末尾カッコ書き
        ]
        for pat in tails {
            if let rx = try? NSRegularExpression(pattern: pat) {
                t = rx.stringByReplacingMatches(in: t, range: NSRange(t.startIndex..., in: t), withTemplate: "")
            }
        }
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
