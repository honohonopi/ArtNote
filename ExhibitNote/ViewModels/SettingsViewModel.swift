import Foundation
import Combine
import UserNotifications

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published private(set) var notificationAuthorizationStatus: UNAuthorizationStatus?
    @Published private(set) var isRequestingAuthorization = false
    @Published private(set) var authorizationErrorMessage: String?

    private let reminderService: ReminderService
    private let settingsStore: SettingsStore

    init(reminderService: ReminderService? = nil, settingsStore: SettingsStore? = nil) {
        self.reminderService = reminderService ?? .shared
        self.settingsStore = settingsStore ?? .shared
    }

    /// 設定画面を開いた時と、設定アプリから戻った時に許可状態を確認する。
    func refreshAuthorization(exhibitions: [Exhibition]) async {
        let previous = notificationAuthorizationStatus
        let current = await reminderService.authorizationStatus()
        notificationAuthorizationStatus = current
        if previous == .denied && current == .authorized {
            rescheduleNotifications(exhibitions: exhibitions)
        }
    }

    /// 未選択の場合に許可を要求する。拒否された場合はViewが設定アプリへの案内を表示する。
    func requestAuthorization(exhibitions: [Exhibition]) async {
        guard !isRequestingAuthorization else { return }
        isRequestingAuthorization = true
        authorizationErrorMessage = nil
        defer { isRequestingAuthorization = false }
        do {
            let granted = try await reminderService.requestAuthorization()
            notificationAuthorizationStatus = await reminderService.authorizationStatus()
            if granted {
                rescheduleNotifications(exhibitions: exhibitions)
            }
        } catch {
            authorizationErrorMessage = "通知の許可を確認できませんでした。もう一度お試しください。"
            notificationAuthorizationStatus = await reminderService.authorizationStatus()
        }
    }

    func rescheduleNotifications(exhibitions: [Exhibition]) {
        let settings = settingsStore.endingSoonNotificationSettings
        Task {
            await reminderService.rescheduleAllNotifications(
                exhibitions: exhibitions,
                isEnabled: settings.isEnabled,
                notificationTime: settings.notificationTime
            )
        }
    }
}
