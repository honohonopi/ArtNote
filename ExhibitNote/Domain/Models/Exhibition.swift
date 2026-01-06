//
//  Exhibition.swift
//  ArtNote
//
//  Created by Honoka Nishiyama on 2025/10/03.
//

// 展覧会の基本モデル
import SwiftUI
import SwiftData
import CoreLocation

@Model
final class Exhibition {
    @Attribute(.unique) var id: String
    // 基本情報
    var title: String
    var venue: String
    var startDate: Date
    var endDate: Date
    var url: URL?
    var tags: [String]
    var catalogTotalCount: Int?
    
    var colorR: Int16?
    var colorG: Int16?
    var colorB: Int16?
    
    var latitude: Double?
    var longitude: Double?
    var address: String?
    
    // ポスター画像
    @Attribute(.externalStorage) var posterThumbData: Data? // 400px程度のJPEG/PNG
    var posterImageId: String?

    // --- 開館情報 ---
    var scheduleOpenTime: String? // 開館時間
    var scheduleCloseTime: String? // 閉館時間
    var scheduleLastEntryTime: String? // 最終受付時間
    var scheduleClosedWeekdays: [String] = [] // 休館曜日
    var scheduleHolidayHandling: String? // 祝日扱い
    var scheduleClosedDates: [Date] = [] // 休館日
    var scheduleOpenDates: [Date] = [] // イレギュラーな開館日
    var scheduleSpecialOpeningsData: Data? // イレギュラーな開館時間を持つ日とその開館時間

    // --- 入館料・予約情報 ---
    var admissionFeesData: Data?
    var reservationRequired: Bool?
    
    var catalogImported: Bool = false // 目録インポート済みフラッグ
    var noteCount: Int? // メモ総数
    var lastViewedNoteIndex: Int? // 最後に閲覧したメモインデックス
    
    // 訪問フラッグ
    var visited: Bool = false
    var visitedAt: Date? = nil
    
    init(id: String = UUID().uuidString,
         title: String,
         venue: String,
         address: String? = nil,
         startDate: Date,
         endDate: Date,
         url: URL? = nil,
         posterImageId: String? = nil,
         tags: [String] = [],
         catalogTotalCount: Int? = nil) {
        self.id = id
        self.title = title
        self.venue = venue
        self.address = address
        self.startDate = startDate
        self.endDate = endDate
        self.url = url
        self.posterImageId = posterImageId
        self.tags = tags
        self.catalogTotalCount = catalogTotalCount
    }
}
