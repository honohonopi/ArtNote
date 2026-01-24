//
//  ReminderService.swift
//  ArtNote
//
//  Created by Honoka Nishiyama on 2025/10/03.
//

// 通知スケジューリング
import UserNotifications

final class ReminderService {
    static let shared = ReminderService()
    private init() {}
    
    func requestAuthorization() async throws {
        _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
    }
    
    func scheduleDeadlineNotifications(for exhibition: Exhibition, isEnabled: Bool, notificationTime: DateComponents) async {
        let center = UNUserNotificationCenter.current()
        await center.removePendingNotificationRequests(withIdentifiers: ["d7_\(exhibition.id)", "d1_\(exhibition.id)"])
        guard isEnabled else { return }

        // D-7
        if let triggerDate = Calendar.current.date(byAdding: .day, value: -7, to: exhibition.endDate), triggerDate > Date() {
            let content = UNMutableNotificationContent()
            content.title = "会期まであと7日"
            content.body = "\(exhibition.title) @ \(exhibition.venue)"
            content.sound = .default

            let date = merge(triggerDate, with: notificationTime)
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

            let date = merge(triggerDate, with: notificationTime)
            let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: false)
            let req = UNNotificationRequest(identifier: "d1_\(exhibition.id)", content: content, trigger: trigger)
            try? await center.add(req)
        }
    }

    func rescheduleAllNotifications(exhibitions: [Exhibition], isEnabled: Bool, notificationTime: DateComponents) async {
        let center = UNUserNotificationCenter.current()
        let ids = exhibitions.flatMap { ["d7_\($0.id)", "d1_\($0.id)"] }
        await center.removePendingNotificationRequests(withIdentifiers: ids)
        guard isEnabled else { return }
        for ex in exhibitions {
            await scheduleDeadlineNotifications(for: ex, isEnabled: true, notificationTime: notificationTime)
        }
    }

    private func merge(_ date: Date, with time: DateComponents) -> DateComponents {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: date)
        comps.hour = time.hour ?? 9
        comps.minute = time.minute ?? 0
        return comps
    }
}
