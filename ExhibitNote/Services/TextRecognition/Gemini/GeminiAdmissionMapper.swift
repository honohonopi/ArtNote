//
//  GeminiAdmissionMapper.swift
//  ExhibitNote
//
//  Created by Honoka Nishiyama on 2026/01/06.
//

import Foundation

enum GeminiAdmissionMapper {

    static func mapFees(_ fees: [GeminiAdmissionFee]) -> [AdmissionFeeRule] {
        fees.compactMap { fee in
            let labelFromPayload = fee.label?.trimmed
            let rawLabel = (labelFromPayload?.isEmpty == false ? labelFromPayload! : (defaultAdmissionLabel(for: fee.category) ?? "不明"))
            let note = fee.note?.trimmed
            var price = fee.priceYen
            let category = fee.category?.trimmed.lowercased()

            if category == "free" {
                price = 0
            }

            if price == nil {
                let t = rawLabel + " " + (note ?? "")
                if t.contains("無料") {
                    price = 0
                }
            }

            return AdmissionFeeRule(
                rawLabel: rawLabel,
                priceYen: price,
                note: note?.isEmpty == false ? note : nil,
                targets: []
            )
        }
    }

    private static func defaultAdmissionLabel(for category: String?) -> String? {
        switch category {
        case "adult": return "一般"
        case "university_student": return "大学生"
        case "high_school_student": return "高校生"
        case "junior_high_student": return "中学生"
        case "elementary_student": return "小学生"
        case "preschool": return "未就学児"
        case "senior": return "シニア"
        case "free": return "無料"
        case "other": return "その他"
        default: return nil
        }
    }
}
