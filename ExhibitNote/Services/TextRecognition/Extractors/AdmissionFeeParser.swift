//
//  AdmissionFeeParser.swift
//  ExhibitNote
//
//  Created by Codex on 2026/01/xx.
//

import Foundation

enum AdmissionFeeParser {
    static func parse(from text: String) -> [AdmissionFeeRule]? {
        let lines = text
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if lines.isEmpty { return nil }

        print("💴 fee-parse input lines: \(lines.count)")

        struct PriceItem {
            let price: Int
            let note: String?
        }

        var results: [AdmissionFeeRule] = []
        var pendingLabels: [String] = []
        var pendingPrices: [PriceItem] = []
        var currentContext: String?

        func flushPending() {
            if !pendingLabels.isEmpty || !pendingPrices.isEmpty {
                print("💴 fee-parse flush: labels=\(pendingLabels), prices=\(pendingPrices.map { $0.price })")
            }
            if pendingLabels.isEmpty, pendingPrices.isEmpty { return }
            let count = min(pendingLabels.count, pendingPrices.count)
            if count > 0 {
                for idx in 0..<count {
                    let label = pendingLabels[idx]
                    let price = pendingPrices[idx]
                    print("💴 fee-parse pair: label=\"\(label)\" price=\(price.price) note=\(price.note ?? currentContext ?? "")")
                    results.append(AdmissionFeeRule(rawLabel: label, priceYen: price.price, note: price.note ?? currentContext))
                }
                pendingLabels.removeFirst(count)
                pendingPrices.removeFirst(count)
            }
            if !pendingLabels.isEmpty, pendingPrices.isEmpty {
                return
            }
            if pendingLabels.isEmpty, !pendingPrices.isEmpty {
                for price in pendingPrices {
                    print("💴 fee-parse price-only: price=\(price.price) note=\(price.note ?? currentContext ?? "")")
                    results.append(AdmissionFeeRule(rawLabel: "入館料", priceYen: price.price, note: price.note ?? currentContext))
                }
                pendingPrices.removeAll()
                return
            }
            if !pendingLabels.isEmpty, !pendingPrices.isEmpty {
                let label = pendingLabels.removeFirst()
                for price in pendingPrices {
                    print("💴 fee-parse one-label-many: label=\"\(label)\" price=\(price.price) note=\(price.note ?? currentContext ?? "")")
                    results.append(AdmissionFeeRule(rawLabel: label, priceYen: price.price, note: price.note ?? currentContext))
                }
                pendingPrices.removeAll()
            }
        }

        for raw in lines {
            if isNoteLine(raw) { continue }
            if isContextLine(raw) {
                print("💴 fee-parse context: \"\(raw)\"")
                flushPending()
                currentContext = raw
                continue
            }
            let parts = splitFeeLine(raw)
            for part in parts {
                if isFreeLike(part) {
                    let label = stripFreeMarkers(part)
                    if !label.isEmpty {
                        print("💴 fee-parse free-labeled: \"\(label)\"")
                        results.append(AdmissionFeeRule(rawLabel: label, priceYen: 0, note: currentContext))
                        continue
                    }
                    if let pending = pendingLabels.first {
                        pendingLabels.removeFirst()
                        print("💴 fee-parse free-pending: \"\(pending)\"")
                        results.append(AdmissionFeeRule(rawLabel: pending, priceYen: 0, note: currentContext))
                    } else {
                        print("💴 fee-parse free-price-only")
                        pendingPrices.append(PriceItem(price: 0, note: currentContext))
                    }
                    continue
                }
                if let price = extractYen(from: part) {
                    let label = stripPrice(part, price: price)
                    let note = extractNote(from: part) ?? currentContext
                    if !label.isEmpty && !isNumericLike(label) {
                        print("💴 fee-parse labeled-price: \"\(label)\" price=\(price) note=\(note ?? "")")
                        results.append(AdmissionFeeRule(rawLabel: label, priceYen: price, note: note))
                    } else {
                        print("💴 fee-parse price-only: price=\(price) note=\(note ?? "")")
                        pendingPrices.append(PriceItem(price: price, note: note))
                    }
                    continue
                }
                // label-only candidate
                if looksLikeLabel(part) {
                    print("💴 fee-parse label: \"\(part)\"")
                    pendingLabels.append(part)
                }
            }
            if !pendingLabels.isEmpty, !pendingPrices.isEmpty {
                flushPending()
            }
        }
        flushPending()
        print("💴 fee-parse results: \(results.map { "\($0.rawLabel)=\($0.priceYen.map(String.init) ?? "未設定")" })")
        return results.isEmpty ? nil : results
    }

    private static func extractYen(from text: String) -> Int? {
        let pattern = #"([0-9]{1,3}(?:,[0-9]{3})+|[0-9]{2,6})\s*円"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let numberRange = Range(match.range(at: 1), in: text)
        else { return nil }
        let raw = text[numberRange].replacingOccurrences(of: ",", with: "")
        return Int(raw)
    }

    private static func splitFeeLine(_ text: String) -> [String] {
        let separators = ["／", "/", "・", "、", "，", "|", "｜", "　", " "]
        var parts: [String] = [text]
        for sep in separators {
            parts = parts.flatMap { $0.split(separator: Character(sep)).map { String($0) } }
        }
        return parts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func isFreeLike(_ text: String) -> Bool {
        let t = text.replacingOccurrences(of: " ", with: "")
        return t.contains("無料") || t.contains("入場無料") || t.contains("観覧無料") || t.lowercased().contains("free")
    }

    private static func stripFreeMarkers(_ text: String) -> String {
        var t = text
        ["入場無料", "観覧無料", "無料", "free", "FREE"].forEach { t = t.replacingOccurrences(of: $0, with: "") }
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func stripPrice(_ text: String, price: Int) -> String {
        var t = text
        t = t.replacingOccurrences(of: "\(price)", with: "")
        let priceWithComma = NumberFormatter.localizedString(from: NSNumber(value: price), number: .decimal)
        t = t.replacingOccurrences(of: priceWithComma, with: "")
        t = t.replacingOccurrences(of: "円", with: "")
        t = t.replacingOccurrences(of: "税込", with: "")
        t = t.replacingOccurrences(of: "(", with: " ").replacingOccurrences(of: ")", with: " ")
        t = t.replacingOccurrences(of: "（", with: " ").replacingOccurrences(of: "）", with: " ")
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func extractNote(from text: String) -> String? {
        if text.contains("団体") || text.contains("前売") || text.contains("当日") || text.contains("割引") || text.contains("学生") {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }

    private static func looksLikeLabel(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return false }
        if t.count <= 1 { return false }
        if t.contains("円") || t.contains("￥") { return false }
        if isNumericLike(t) { return false }
        return true
    }

    private static func isNoteLine(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.hasPrefix("※") || t.hasPrefix("*")
    }

    private static func isContextLine(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return false }
        if extractYen(from: t) != nil { return false }
        return t.contains("前売") || t.contains("当日") || t.contains("当日券") || t.contains("前売券") || t.contains("チケット")
    }

    private static func isNumericLike(_ text: String) -> Bool {
        let t = text.replacingOccurrences(of: ",", with: "").replacingOccurrences(of: " ", with: "")
        return !t.isEmpty && t.allSatisfy { $0.isNumber }
    }
}
