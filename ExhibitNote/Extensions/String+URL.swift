//
//  String+URL.swift
//  ExhibitNote
//
//  Created by Codex on 2026/01/xx.
//

import Foundation

extension String {
    func normalizedWebURL() -> URL? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let url = URL(string: trimmed),
           let scheme = url.scheme?.lowercased(),
           (scheme == "http" || scheme == "https"),
           url.host != nil {
            return url
        }

        if let url = URL(string: "https://\(trimmed)"),
           url.host != nil {
            return url
        }

        return nil
    }
}
