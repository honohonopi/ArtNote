//
//  ArtworkNote.swift
//  ArtNote
//
//  Created by Honoka Nishiyama on 2025/10/03.
//

// 作品ごとのメモ
import Foundation
import SwiftData

@Model
final class ArtworkNote {
    @Attribute(.unique) var id: String
    var exhibitionId: String
    var catalogNumber: String
    var catalogIndex: Int?
    var displayCatalogNumber: String?
    var memo: String
    var audioId: String?
    var createdAt: Date
    var updatedAt: Date
    
    // --- 追加（最小構成の作品メタ） ---
    var artworkTitle: String?
    var artist: String?
    var yearText: String?          // 例: "1890 (明治23)"
    var material: String?          // 例: "油彩・キャンバス"
    var collection: String?        // 例: "東京国立博物館蔵"
    
    @Attribute(.externalStorage) var photoThumbData: Data? // 作品の小さいサムネ
    
    init(id: String = UUID().uuidString,
         exhibitionId: String,
         catalogNumber: String,
         catalogIndex: Int? = nil,
         displayCatalogNumber: String? = nil,
         memo: String,
         audioId: String? = nil,
         createdAt: Date = .now,
         updatedAt: Date = .now) {
        self.id = id
        self.exhibitionId = exhibitionId
        self.catalogNumber = catalogNumber
        self.catalogIndex = catalogIndex
        self.displayCatalogNumber = displayCatalogNumber
        self.memo = memo
        self.audioId = audioId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension ArtworkNote {
    var resolvedDisplayNumber: String {
        if let d = displayCatalogNumber?.trimmingCharacters(in: .whitespacesAndNewlines),
           !d.isEmpty {
            return d
        }
        return catalogNumber
    }
    
    var resolvedCatalogIndex: Int {
        if let i = catalogIndex { return i }
        return Int(catalogNumber) ?? 0
    }
}
