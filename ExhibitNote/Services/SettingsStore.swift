import Foundation
import Observation

/// アプリ内で共有する設定。変更をViewに通知し、UserDefaultsへ保存する。
/// 保存済み設定を引き継ぐため、保存キーの旧名は維持する。
@MainActor
@Observable
final class SettingsStore {
    static let shared = SettingsStore()

    var endingSoonNotificationSettings: EndingSoonNotificationSettings {
        didSet {
            defaults.set(endingSoonNotificationSettings.isEnabled, forKey: "notifyDeadlineEnabled")
            defaults.set(endingSoonNotificationSettings.hour, forKey: "notifyDeadlineHour")
            defaults.set(endingSoonNotificationSettings.minute, forKey: "notifyDeadlineMinute")
        }
    }
    var includeVisitedSuggestions: Bool {
        didSet { defaults.set(includeVisitedSuggestions, forKey: "includeVisitedSuggestions") }
    }
    var notifyNearbyOpenEnabled: Bool {
        didSet { defaults.set(notifyNearbyOpenEnabled, forKey: "notifyNearbyOngoingEnabled") }
    }
    var notifyNearbyRadiusKm: Double {
        didSet { defaults.set(notifyNearbyRadiusKm, forKey: "notifyNearbyRadiusKm") }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let fallback = EndingSoonNotificationSettings()
        self.endingSoonNotificationSettings = EndingSoonNotificationSettings(
            isEnabled: (defaults.object(forKey: "notifyDeadlineEnabled") as? Bool) ?? fallback.isEnabled,
            hour: (defaults.object(forKey: "notifyDeadlineHour") as? Int) ?? fallback.hour,
            minute: (defaults.object(forKey: "notifyDeadlineMinute") as? Int) ?? fallback.minute
        )
        self.includeVisitedSuggestions = defaults.bool(forKey: "includeVisitedSuggestions")
        self.notifyNearbyOpenEnabled = defaults.bool(forKey: "notifyNearbyOngoingEnabled")
        self.notifyNearbyRadiusKm = (defaults.object(forKey: "notifyNearbyRadiusKm") as? Double) ?? 10
    }
}
