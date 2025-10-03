//
//  Reminder.swift
//  ArtNote
//
//  Created by Honoka Nishiyama on 2025/10/03.
//

import Foundation
import SwiftData


enum ReminderType: String, Codable, CaseIterable, Identifiable {
    case d7 = "D-7"
    case d1 = "D-1"
    case geo = "geo"
    var id: String { rawValue }
}

@Model
final class Reminder {
    @Attribute(.unique) var id: String
    var exhibitionId: String
    var type: ReminderType
    var isEnabled: Bool
    
    
    init(id: String = UUID().uuidString,
         exhibitionId: String,
         type: ReminderType,
         isEnabled: Bool = true) {
        self.id = id
        self.exhibitionId = exhibitionId
        self.type = type
        self.isEnabled = isEnabled
    }
}
