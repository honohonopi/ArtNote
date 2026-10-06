import Foundation

/// メモ内で最後に入力された作品番号から、次の番号候補を生成する。
struct MemoNumberSuggestionGenerator {
    static func suggestions(from text: String) -> [String] {
        let lastToken = lastNumberToken(in: text)
        if let lastToken, let nextNumbers = nextCandidates(from: lastToken) {
            return nextNumbers
        }
        return (1...5).map { "\($0)" }
    }

    private static func lastNumberToken(in text: String) -> String? {
        let pattern = #"#([A-Za-z0-9_\-]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        guard let last = matches.last, last.numberOfRanges > 1 else { return nil }
        guard let range = Range(last.range(at: 1), in: text) else { return nil }
        return String(text[range])
    }

    private static func nextCandidates(from token: String) -> [String]? {
        let pattern = #"(.*?)(\d+)(\D*)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let range = NSRange(location: 0, length: token.utf16.count)
        guard let match = regex.firstMatch(in: token, options: [], range: range) else { return nil }
        guard let prefixRange = Range(match.range(at: 1), in: token),
              let numberRange = Range(match.range(at: 2), in: token),
              let suffixRange = Range(match.range(at: 3), in: token)
        else { return nil }
        let prefix = String(token[prefixRange])
        let numberText = String(token[numberRange])
        let suffix = String(token[suffixRange])
        guard let base = Int(numberText) else { return nil }
        let width = numberText.count
        return (1...5).map { offset in
            let next = base + offset
            let padded = String(format: "%0*d", width, next)
            return "\(prefix)\(padded)\(suffix)"
        }
    }
}
