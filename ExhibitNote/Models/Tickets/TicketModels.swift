//
//  TicketModels.swift
//  ExhibitNote
//
//  Created by Honoka Nishiyama on 2026/01/06.
//

import Foundation

// 設定画面でユーザーが選ぶ属性
enum UserTicketCategory: String, CaseIterable, Codable, Identifiable {
    case senior
    case adult
    case universityStudent
    case vocationalStudent
    case highSchoolStudent
    case juniorHighStudent
    case elementaryStudent
    case preschool

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .senior: return "シニア"
        case .adult: return "一般"
        case .universityStudent: return "大学生"
        case .vocationalStudent: return "専門学生"
        case .highSchoolStudent: return "高校生"
        case .juniorHighStudent: return "中学生"
        case .elementaryStudent: return "小学生"
        case .preschool: return "未就学児"
        }
    }
}

/// ポスターに書かれた1行(1区分)の入館料を保存する
/// - rawLabel: 「高校生・大学生」など原文を保持
/// - targets: アプリ側で（ルール or ユーザー編集で）この料金が適用される属性を入れる

struct AdmissionFeeRule: Codable, Identifiable {
    var id: String = UUID().uuidString

    var rawLabel: String
    /// priceYen:
    /// - 0: free (explicitly stated)
    /// - nil: unknown / discount-only / not a numeric price
    var priceYen: Int?
    var note: String?
    var targets: [UserTicketCategory]

    init(rawLabel: String,
         priceYen: Int?,
         note: String? = nil,
         targets: [UserTicketCategory] = []) {
        self.rawLabel = rawLabel
        self.priceYen = priceYen
        self.note = note
        self.targets = targets
    }

    /// “free” として扱ってよいか（基本は 0 のみ）
    var isFreeLike: Bool {
        priceYen == 0
    }
}

extension Array where Element == AdmissionFeeRule {

    /// ユーザー属性に合う料金を「安全に」解決する（誤表示しない）
    /// - 方針:
    ///   - targets が空のルールは “未設定/不明” とみなし、解決には使わない
    ///   - targets が設定されているルールの中から一致のみ返す
    ///   - 一致がない/解決不能なら nil
    func resolvedFee(for user: UserTicketCategory) -> AdmissionFeeRule? {
        let configured = self.filter { !$0.targets.isEmpty }

        // targets が空しかない（=まだマッピングされていない）なら誤表示防止で nil
        guard !configured.isEmpty else { return nil }

        // 完全一致（安全）
        return configured.first(where: { $0.targets.contains(user) })
    }

    var isReadyForUserSpecificDisplay: Bool {
        self.contains { !$0.targets.isEmpty }
    }

    var hasUnmappedRules: Bool {
        self.contains { $0.targets.isEmpty }
    }
}
