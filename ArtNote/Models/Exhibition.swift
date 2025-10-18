//
//  Exhibition.swift
//  ArtNote
//
//  Created by Honoka Nishiyama on 2025/10/03.
//

// 展覧会の基本モデル
import Foundation
import SwiftData

@Model
final class Exhibition {
    @Attribute(.unique) var id: String
    var title: String
    var venue: String
    var startDate: Date
    var endDate: Date
    var url: URL?
    var posterImageId: String?
    var tags: [String]
    var catalogTotalCount: Int?
    
    init(id: String = UUID().uuidString,
         title: String,
         venue: String,
         startDate: Date,
         endDate: Date,
         url: URL? = nil,
         posterImageId: String? = nil,
         tags: [String] = [],
         catalogTotalCount: Int? = nil) {
        self.id = id
        self.title = title
        self.venue = venue
        self.startDate = startDate
        self.endDate = endDate
        self.url = url
        self.posterImageId = posterImageId
        self.tags = tags
        self.catalogTotalCount = catalogTotalCount
    }
}
