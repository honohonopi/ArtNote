//
//  String+Trimmed.swift
//  ExhibitNote
//
//  Created by Honoka Nishiyama on 2026/01/06.
//

import Foundation

extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
