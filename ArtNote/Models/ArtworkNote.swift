//
//  ArtworkNote.swift
//  ArtNote
//
//  Created by Honoka Nishiyama on 2025/10/03.
//

import Foundation
import SwiftData


@Model
final class ArtworkNote {
    @Attribute(.unique) var id: String
    var exhibitionId: String
    var catalogNumber: String
    var memo: String
    var audioId: String?
    var createdAt: Date
    var updatedAt: Date
    
    
    init(id: String = UUID().uuidString,
         exhibitionId: String,
         catalogNumber: String,
         memo: String,
         audioId: String? = nil,
         createdAt: Date = .now,
         updatedAt: Date = .now) {
        self.id = id
        self.exhibitionId = exhibitionId
        self.catalogNumber = catalogNumber
        self.memo = memo
        self.audioId = audioId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
