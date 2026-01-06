//
//  JSONSnippetExtractor.swift
//  ExhibitNote
//
//  Created by Honoka Nishiyama on 2026/01/06.
//

import Foundation

enum JSONSnippetExtractor {
    static func extractFirstJSON(from text: String) -> String? {
        guard let start = text.firstIndex(of: "{"),
              let end = text.lastIndex(of: "}")
        else {
            return nil
        }
        return String(text[start...end])
    }
}
