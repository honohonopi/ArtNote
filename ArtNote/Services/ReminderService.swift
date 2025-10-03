//
//  ReminderService.swift
//  ArtNote
//
//  Created by Honoka Nishiyama on 2025/10/03.
//

import UserNotifications


final class ReminderService {
    static let shared = ReminderService()
    private init() {}
    
    func requestAuthorization() async throws {
        _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
    }
    
    func scheduleDeadlineNotifications(for exhibition: Exhibition) async {
        let center = UNUserNotificationCenter.current()
        await center.removePendingNotificationRequests(withIdentifiers: ["d7_\(exhibition.id)", "d1_\(exhibition.id)"])
        
        
        // D-7
        if let triggerDate = Calendar.current.date(byAdding: .day, value: -7, to: exhibition.endDate), triggerDate > Date() {
            let content = UNMutableNotificationContent()
            content.title = "会期まであと7日"
            content.body = "\(exhibition.title) @ \(exhibition.venue)"
            content.sound = .default
            
            
            let date = Calendar.current.dateComponents([.year,.month,.day,.hour,.minute], from: triggerDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: false)
            let req = UNNotificationRequest(identifier: "d7_\(exhibition.id)", content: content, trigger: trigger)
            try? await center.add(req)
        }
        // D-1
        if let triggerDate = Calendar.current.date(byAdding: .day, value: -1, to: exhibition.endDate), triggerDate > Date() {
            let content = UNMutableNotificationContent()
            content.title = "会期は明日まで"
            content.body = "\(exhibition.title) @ \(exhibition.venue)"
            content.sound = .default
            
            
            let date = Calendar.current.dateComponents([.year,.month,.day,.hour,.minute], from: triggerDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: false)
            let req = UNNotificationRequest(identifier: "d1_\(exhibition.id)", content: content, trigger: trigger)
            try? await center.add(req)
        }
    }
}
