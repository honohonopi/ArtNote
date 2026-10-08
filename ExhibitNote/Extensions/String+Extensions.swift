import Foundation

extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func normalizedWebURL() -> URL? {
        let value = trimmed
        guard !value.isEmpty else { return nil }

        if let url = URL(string: value),
           let scheme = url.scheme?.lowercased(),
           (scheme == "http" || scheme == "https"),
           url.host != nil {
            return url
        }

        if let url = URL(string: "https://\(value)"), url.host != nil {
            return url
        }

        return nil
    }
}
