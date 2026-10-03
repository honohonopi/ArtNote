//
//  Exhibition+Ticket.swift
//  ExhibitNote
//
//  Created by Honoka Nishiyama on 2026/01/06.
//

import Foundation

extension Exhibition {

    // MARK: - Admission Fee Rules (canonical)

    /// チケット情報の正規モデル：
    /// TicketModels.swift の AdmissionFeeRule を JSON で保存する
    var admissionFeeRules: [AdmissionFeeRule] {
        get {
            guard let data = admissionFeesData, !data.isEmpty else { return [] }
            return (try? JSONDecoder().decode([AdmissionFeeRule].self, from: data)) ?? []
        }
        set {
            admissionFeesData = try? JSONEncoder().encode(newValue)
        }
    }

    /// 設定画面で選んだユーザー属性に対して、表示すべき料金行を返す
    func resolvedAdmissionFee(for user: UserTicketCategory) -> AdmissionFeeRule? {
        admissionFeeRules.resolvedFee(for: user)
    }

    // MARK: - Convenience

    /// 「無料」と明示された料金が1つでもあれば true（参考用）
    var hasFreeAdmissionOption: Bool {
        admissionFeeRules.contains { $0.isFreeLike }
    }
}
