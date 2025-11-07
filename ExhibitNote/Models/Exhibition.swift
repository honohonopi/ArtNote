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
    var title: String
    var venue: String
    var startDate: Date
    var endDate: Date
    var url: URL?
    var posterImageId: String?
    var tags: [String]
    var catalogTotalCount: Int?
    
    var colorR: Int16?
    var colorG: Int16?
    var colorB: Int16?
    
    var latitude: Double?
    var longitude: Double?
    var address: String?
    
    // 訪問フラッグ
    var visited: Bool = false
    var visitedAt: Date? = nil
    
    // ステータス（未開催/開催中/終了）
    enum RunStatus: String, CaseIterable, Identifiable {
        case notStarted, ongoing, finished
        var id: Self { self }
        var label: String {
            switch self {
            case .notStarted: return "未開催"
            case .ongoing:    return "開催中"
            case .finished:   return "終了"
            }
        }
    }
    
    @Attribute(.externalStorage) var posterThumbData: Data? // 400px程度のJPEG/PNG
    
    var runStatus: RunStatus {
        let today = Calendar.current.startOfDay(for: Date())
        let sd = Calendar.current.startOfDay(for: startDate)
        let ed = Calendar.current.startOfDay(for: endDate)

        if today < sd { return .notStarted }
        if today > ed { return .finished }
        return .ongoing
    }
    
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
    
    var uiColor: UIColor? {
        guard let r = colorR, let g = colorG, let b = colorB else { return nil }
        return UIColor(red: CGFloat(r)/255, green: CGFloat(g)/255, blue: CGFloat(b)/255, alpha: 1)
    }
    var swiftUIColor: Color? {
        guard let c = uiColor else { return nil }
        return Color(cgColor: c.cgColor)
    }
    
    func setColor(_ color: UIColor) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 1
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        colorR = Int16((r * 255).rounded())
        colorG = Int16((g * 255).rounded())
        colorB = Int16((b * 255).rounded())
    }
    
    var hasCoordinate: Bool { latitude != nil && longitude != nil }
    var coordinate: CLLocationCoordinate2D? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
    func setCoordinate(_ c: CLLocationCoordinate2D) {
        latitude = c.latitude; longitude = c.longitude
    }
}
