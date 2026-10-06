import Foundation
import Observation
import SwiftData
import UserNotifications

@MainActor
@Observable
final class SettingsViewModel {
    private(set) var notificationAuthorizationStatus: UNAuthorizationStatus?
    private(set) var isRequestingAuthorization = false
    private(set) var authorizationErrorMessage: String?

    private let reminderService: ReminderService

    init(reminderService: ReminderService? = nil) {
        self.reminderService = reminderService ?? .shared
    }

    /// 設定画面を開いた時と、設定アプリから戻った時に許可状態を確認する。
    func refreshAuthorization(in context: ModelContext) async {
        let previous = notificationAuthorizationStatus
        let current = await reminderService.authorizationStatus()
        notificationAuthorizationStatus = current
        if previous == .denied && current == .authorized {
            rescheduleNotifications(in: context)
        }
    }

    /// 未選択の場合に許可を要求する。拒否された場合はViewが設定アプリへの案内を表示する。
    func requestAuthorization(in context: ModelContext) async {
        guard !isRequestingAuthorization else { return }
        isRequestingAuthorization = true
        authorizationErrorMessage = nil
        defer { isRequestingAuthorization = false }
        do {
            let granted = try await reminderService.requestAuthorization()
            notificationAuthorizationStatus = await reminderService.authorizationStatus()
            if granted {
                rescheduleNotifications(in: context)
            }
        } catch {
            authorizationErrorMessage = "通知の許可を確認できませんでした。もう一度お試しください。"
            notificationAuthorizationStatus = await reminderService.authorizationStatus()
        }
    }

    func rescheduleNotifications(in context: ModelContext) {
        Task {
            await reminderService.rescheduleAllNotifications(in: context)
        }
    }
}
