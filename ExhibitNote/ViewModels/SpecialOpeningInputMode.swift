//
//  SpecialOpeningInputMode.swift
//  ExhibitNote
//
//  Created by Honoka Nishiyama on 2026/01/06.
//

import Foundation

enum SpecialOpeningInputMode: String, CaseIterable, Identifiable {
    case date
    case weekday
    case range

    var id: String { rawValue }

    var label: String {
        switch self {
        case .date: return "単日"
        case .weekday: return "曜日"
        case .range: return "期間"
        }
    }
}
