import Foundation
import Combine
import CoreLocation
import SwiftData

/// Prepares home-screen data and coordinates nearby exhibition notifications.
@MainActor
final class HomeViewModel: ObservableObject {
    @Published private(set) var nearbyExhibitions: [(Exhibition, Double)] = []

    @Published private(set) var notificationAuthorizationGranted: Bool?

    private let fixedNow: Date?
    private var now: Date { fixedNow ?? Date() }
    private var isSchedulingNearby = false
    private let defaults: UserDefaults
    private let reminderService: ReminderService

    init(
        now: Date? = nil,
        defaults: UserDefaults = .standard,
        reminderService: ReminderService? = nil
    ) {
        self.fixedNow = now
        self.defaults = defaults
        self.reminderService = reminderService ?? .shared
    }

    func requestNotificationAuthorization(in context: ModelContext) async {
        notificationAuthorizationGranted = try? await reminderService.requestAuthorization()
        if notificationAuthorizationGranted == true {
            await reminderService.retryPendingEndingSoonNotifications(in: context)
        }
    }

    func soonExhibitions(from allExhibitions: [Exhibition], within soonDays: Int) -> [Exhibition] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        let upper = cal.date(byAdding: .day, value: soonDays, to: today)!
        return allExhibitions
            .filter { $0.endDate >= today && $0.endDate < upper }
            .sorted { $0.endDate < $1.endDate }
    }

    private func distanceKm(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        CLLocation(latitude: a.latitude, longitude: a.longitude)
            .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude)) / 1000.0
    }

    func recomputeNearby(
        exhibitions allExhibitions: [Exhibition],
        coordinate: CLLocationCoordinate2D?,
        radiusKm nearbyRadiusKm: Double
    ) {
        guard let here = coordinate else {
            nearbyExhibitions = []
            return
        }
        let today = Calendar.current.startOfDay(for: now)
        let running = allExhibitions.filter {
            $0.hasCoordinate && $0.startDate <= today && $0.endDate >= today
        }
        var paired: [(Exhibition, Double)] = []
        paired.reserveCapacity(running.count)
        for ex in running {
            if let c = ex.coordinate {
                paired.append((ex, distanceKm(c, here)))
            }
        }
        let limited = paired.filter { $0.1 <= nearbyRadiusKm }
        nearbyExhibitions = limited.sorted { $0.1 < $1.1 }
    }

    func checkNearbyOpenNotification(
        isEnabled notifyNearbyOpenEnabled: Bool,
        coordinate: CLLocationCoordinate2D?,
        radiusKm notifyNearbyRadiusKm: Double
    ) {
        guard notifyNearbyOpenEnabled, !isSchedulingNearby else { return }
        let now = now
        guard coordinate != nil else { return }
        let todayKey = ymdKey(now)
        guard defaults.string(forKey: "notifyNearbyLastDate") != todayKey else { return }
        guard let target = nearbyExhibitions.first(where: { isNotifyTarget($0.0, now: now, distanceKm: $0.1, radiusKm: notifyNearbyRadiusKm) }) else { return }
        isSchedulingNearby = true
        Task {
            defer { isSchedulingNearby = false }
            let succeeded = await reminderService.scheduleNearbyOpenNotification(
                for: target.0,
                identifier: "nearby_\(todayKey)"
            )
            if succeeded {
                defaults.set(todayKey, forKey: "notifyNearbyLastDate")
            }
        }
    }

    private func isNotifyTarget(_ exhibition: Exhibition, now: Date, distanceKm: Double, radiusKm: Double) -> Bool {
        guard distanceKm <= radiusKm else { return false }
        let status = ExhibitionScheduleUtils.openingStatus(on: now, exhibition: exhibition)
        guard case .open(let openTime, let closeTime, let lastEntryTime) = status else { return false }
        if let open = timeOnToday(openTime, now: now), now < open { return false }
        let cutoff: Date
        if let last = timeOnToday(lastEntryTime, now: now) {
            cutoff = Calendar.current.date(byAdding: .minute, value: -30, to: last) ?? last
        } else if let close = timeOnToday(closeTime, now: now) {
            cutoff = Calendar.current.date(byAdding: .minute, value: -60, to: close) ?? close
        } else {
            cutoff = Calendar.current.date(bySettingHour: 16, minute: 0, second: 0, of: now) ?? now
        }
        return now <= cutoff
    }

    private func timeOnToday(_ timeString: String?, now: Date) -> Date? {
        guard let timeString else { return nil }
        let trimmed = timeString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != "未設定" else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        guard let time = formatter.date(from: trimmed) else { return nil }
        let comps = Calendar.current.dateComponents([.hour, .minute], from: time)
        return Calendar.current.date(bySettingHour: comps.hour ?? 0, minute: comps.minute ?? 0, second: 0, of: now)
    }

    private func ymdKey(_ date: Date) -> String {
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: date)
        guard let y = comps.year, let m = comps.month, let d = comps.day else { return "" }
        return String(format: "%04d-%02d-%02d", y, m, d)
    }
}
