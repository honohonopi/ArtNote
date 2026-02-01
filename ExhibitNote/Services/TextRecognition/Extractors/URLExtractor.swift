//
//  URLExtractor.swift
//  ExhibitNote
//
//  Created by Honoka Nishiyama on 2026/01/06.
//

import Foundation

enum URLExtractor {
    static func extractURLs(from text: String) -> [String] {
        let normalized = normalizeText(text)
        let patterns = [
            #"https?://[^\s]+"#,
            #"(?:www\.)?[A-Za-z0-9\-]+(?:\.[A-Za-z0-9\-]+)+(?:/[^\s]*)?"#
        ]

        var results: [String] = []
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { continue }
            let ns = normalized as NSString
            for match in regex.matches(in: normalized, range: NSRange(location: 0, length: ns.length)) {
                let raw = ns.substring(with: match.range)
                if let cleaned = normalizeURLCandidate(raw), !results.contains(cleaned) {
                    results.append(cleaned)
                }
            }
        }
        return results
    }

    private static func normalizeText(_ text: String) -> String {
        let converted = text.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? text
        return converted
            .replacingOccurrences(of: "：", with: ":")
            .replacingOccurrences(of: "／", with: "/")
            .replacingOccurrences(of: "．", with: ".")
    }

    private static func normalizeURLCandidate(_ raw: String) -> String? {
        var t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return nil }
        t = t.trimmingCharacters(in: CharacterSet(charactersIn: ".,。、:;)]}＞>」』）"))
        t = t.trimmingCharacters(in: CharacterSet(charactersIn: "([<{「『（"))

        if t.lowercased().hasPrefix("www.") {
            t = "https://" + t
        }
        if !t.lowercased().hasPrefix("http://") && !t.lowercased().hasPrefix("https://") {
            t = "https://" + t
        }

        guard let comps = URLComponents(string: t),
              let host = comps.host?.lowercased(),
              isValidHost(host)
        else { return nil }

        if let path = comps.percentEncodedPath.removingPercentEncoding,
           path.contains(" ") {
            return nil
        }

        return comps.url?.absoluteString
    }

    private static func isValidHost(_ host: String) -> Bool {
        if host.isEmpty { return false }
        if host.hasPrefix("-") || host.hasSuffix("-") { return false }
        if host.hasPrefix(".") || host.hasSuffix(".") { return false }
        if host.hasPrefix("..") || host.contains("..") { return false }
        if host.contains("_") { return false }

        let parts = host.split(separator: ".")
        if parts.count < 2 { return false }
        if parts.contains(where: { $0.isEmpty }) { return false }

        let tld = parts.last ?? ""
        if tld.count < 2 || tld.count > 24 { return false }
        if tld.allSatisfy({ $0.isNumber }) { return false }
        if !tld.allSatisfy({ $0.isLetter }) { return false }

        for label in parts {
            if label.count > 63 { return false }
            if label.hasPrefix("-") || label.hasSuffix("-") { return false }
            if !label.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" }) {
                return false
            }
        }
        return true
    }
}
