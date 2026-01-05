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

    var catalogImported: Bool = false
    var noteCount: Int?
    var lastViewedNoteIndex: Int?

    // --- 開館スケジュール（AI候補を保存） ---
    var scheduleOpenTime: String?
    var scheduleCloseTime: String?
    var scheduleLastEntryTime: String?
    var scheduleClosedWeekdays: [String] = []
    var scheduleHolidayHandling: String?
    var scheduleClosedDates: [Date] = []
    var scheduleOpenDates: [Date] = []
    var scheduleSpecialOpeningsData: Data?

    // --- 入館料・予約情報 ---
    var admissionFeesData: Data?
    var reservationRequired: Bool?
    
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

    struct SpecialOpeningRecord: Codable {
        let ruleType: String   // "date" or "weekday"
        let date: Date?
        let weekday: String?
        let openTime: String
        let closeTime: String
        let lastEntryTime: String?
        let note: String?
    }
    
    var scheduleSpecialOpenings: [SpecialOpeningRecord] {
        get {
            guard let data = scheduleSpecialOpeningsData else { return [] }
            return (try? JSONDecoder().decode([SpecialOpeningRecord].self, from: data)) ?? []
        }
        set {
            scheduleSpecialOpeningsData = try? JSONEncoder().encode(newValue)
        }
    }

    var admissionFees: [AdmissionFee] {
        get {
            guard let data = admissionFeesData else { return [] }
            return (try? JSONDecoder().decode([AdmissionFee].self, from: data)) ?? []
        }
        set {
            admissionFeesData = try? JSONEncoder().encode(newValue)
        }
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

enum UserAdmissionCategory: String, CaseIterable, Identifiable {
    case adult
    case universityStudent
    case highSchoolStudent
    case juniorHighStudent
    case elementaryStudent
    case preschool
    case senior
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .adult: return "一般"
        case .universityStudent: return "大学生"
        case .highSchoolStudent: return "高校生"
        case .juniorHighStudent: return "中学生"
        case .elementaryStudent: return "小学生"
        case .preschool: return "未就学児"
        case .senior: return "シニア"
        }
    }
}

extension AdmissionFee {
    func applies(to user: UserAdmissionCategory) -> Bool {
        switch category {
        case .adult:
            return user == .adult
        case .universityStudent:
            return user == .universityStudent
        case .highSchoolStudent:
            return user == .highSchoolStudent || user == .juniorHighStudent
        case .juniorHighStudent:
            return user == .juniorHighStudent
        case .elementaryStudent:
            return user == .elementaryStudent || user == .preschool
        case .preschool:
            return user == .preschool
        case .senior:
            return user == .senior
        case .free:
            return true
        case .other:
            return false
        }
    }
}

func resolvedFee(for user: UserAdmissionCategory, fees: [AdmissionFee]) -> AdmissionFee? {
    if let match = fees.first(where: { $0.applies(to: user) }) {
        return match
    }
    if let free = fees.first(where: { $0.category == .free }) {
        return free
    }
    return fees.first(where: { $0.category == .adult })
}

enum AdmissionCategory: String, Codable, CaseIterable {
    case adult = "adult"
    case universityStudent = "university_student"
    case highSchoolStudent = "high_school_student"
    case juniorHighStudent = "junior_high_student"
    case elementaryStudent = "elementary_student"
    case preschool = "preschool"
    case senior = "senior"
    case free = "free"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .adult: return "一般"
        case .universityStudent: return "大学生"
        case .highSchoolStudent: return "高校生"
        case .juniorHighStudent: return "中学生"
        case .elementaryStudent: return "小学生"
        case .preschool: return "未就学児"
        case .senior: return "シニア"
        case .free: return "無料"
        case .other: return "その他"
        }
    }
}

struct AdmissionFee: Codable, Identifiable {
    let id = UUID()
    let category: AdmissionCategory
    let label: String
    let priceYen: Int?
    let note: String?
    
    private enum CodingKeys: String, CodingKey {
        case category
        case label
        case priceYen = "price_yen"
        case note
    }

    init(category: AdmissionCategory, label: String, priceYen: Int?, note: String? = nil) {
        self.category = category
        self.label = label
        self.note = note
        if category == .free {
            self.priceYen = nil
        } else {
            self.priceYen = priceYen
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        category = try container.decode(AdmissionCategory.self, forKey: .category)
        label = try container.decode(String.self, forKey: .label)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        let decodedPrice = try container.decodeIfPresent(Int.self, forKey: .priceYen)
        if category == .free {
            priceYen = nil
        } else {
            priceYen = decodedPrice
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(category, forKey: .category)
        try container.encode(label, forKey: .label)
        try container.encodeIfPresent(note, forKey: .note)
        if category != .free {
            try container.encodeIfPresent(priceYen, forKey: .priceYen)
        }
    }
}
