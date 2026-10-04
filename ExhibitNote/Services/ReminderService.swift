import Foundation
import UserNotifications
import SwiftData
import OSLog

/// 通知の予約と、失敗した期限通知の再試行を管理する。
@MainActor
final class ReminderService {
    static let shared = ReminderService()

    private let client: any NotificationClient
    private let defaults: UserDefaults
    private let settingsStore: SettingsStore
    private let clock: () -> Date
    private let logger = Logger(subsystem: "ExhibitNote", category: "Notifications")
    // 保存済みの再試行データを引き継ぐため、保存キーの旧名は維持する。
    private let pendingKey = "pendingDeadlineNotificationIDs"
    private let attemptsKey = "deadlineNotificationLastAttempts"
    private let retryInterval: TimeInterval = 60
    private var tail: Task<Void, Never>?
    private var revisions: [String: UUID] = [:]
    private var queuedIDs: Set<String> = []
    private var lastNearbyFailure: Date?
    private var isMigratingTimeZone = false

    init(
        client: (any NotificationClient)? = nil,
        defaults: UserDefaults? = nil,
        clock: @escaping () -> Date = Date.init
    ) {
        self.client = client ?? SystemNotificationClient()
        self.defaults = defaults ?? .standard
        self.settingsStore = defaults.map { SettingsStore(defaults: $0) } ?? .shared
        self.clock = clock
    }

    private static let endingSoonReminders: [(daysBefore: Int, title: String)] = [
        (7, "会期まであと7日"),
        (1, "会期は明日まで")
    ]

    private var pendingIDs: Set<String> {
        get { Set(defaults.stringArray(forKey: pendingKey) ?? []) }
        set { defaults.set(newValue.sorted(), forKey: pendingKey) }
    }

    /// 7日前・1日前の通知を同じ識別子で更新し、重複予約を防ぐ。
    private func endingSoonNotificationIDs(for exhibitionID: String) -> [String] {
        Self.endingSoonReminders.map { "d\($0.daysBefore)_\(exhibitionID)" }
    }

    /// 削除後の再試行と実行中の古い予約を無効化し、予約済み・配信済み通知を除去する。
    func cancelEndingSoonNotifications(exhibitionID: String) {
        revisions[exhibitionID] = UUID()
        queuedIDs.remove(exhibitionID)
        finish(exhibitionID)
        let ids = endingSoonNotificationIDs(for: exhibitionID)
        client.removePending(ids)
        client.removeDelivered(ids)
    }

    /// 許可ならtrue、拒否ならfalseを返す。要求処理の失敗はエラーとして返す。
    func requestAuthorization() async throws -> Bool {
        try await client.requestAuthorization()
    }

    /// 設定アプリでの変更を含め、現在の通知許可状態を取得する。
    func authorizationStatus() async -> UNAuthorizationStatus {
        await client.authorizationStatus()
    }

    private func canSchedule(_ status: UNAuthorizationStatus) -> Bool {
        #if os(iOS)
        if status == .ephemeral { return true }
        #endif
        return status == .authorized || status == .provisional
    }

    /// 保存後の期限通知を再設定する。予約失敗は記録し、展覧会の保存失敗にはしない。
    func scheduleEndingSoonNotifications(for exhibition: Exhibition, isEnabled: Bool, notificationTime: DateComponents) async {
        let task = enqueue(exhibitionID: exhibition.id) { [self] in
            await schedule(exhibition: exhibition, isEnabled: isEnabled, time: notificationTime)
        }
        await task.value
    }

    /// 全件を先にキューへ登録し、最新の設定変更が古い設定に上書きされないようにする。
    /// 解除は各件に任せ、OFFの場合は予約と再試行対象を除去する。
    func rescheduleAllNotifications(exhibitions: [Exhibition], isEnabled: Bool, notificationTime: DateComponents) async {
        let tasks = exhibitions.map { exhibition in
            enqueue(exhibitionID: exhibition.id) { [self] in
                await schedule(exhibition: exhibition, isEnabled: isEnabled, time: notificationTime)
            }
        }
        for task in tasks { await task.value }
    }

    /// 起動・復帰時に、失敗した期限通知だけを再設定する。バックグラウンドの定期実行は行わない。
    /// データ取得に失敗した場合は保留し、実行時に最新のデータ・設定を読み直す。
    func retryPendingEndingSoonNotifications(in context: ModelContext) async {
        await migrateNotificationTimeZoneIfNeeded(in: context)
        let tasks = pendingIDs.sorted().compactMap { id -> Task<Void, Never>? in
            guard !queuedIDs.contains(id) else { return nil }
            return enqueue(exhibitionID: id) { [self] in
                do {
                    let descriptor = FetchDescriptor<Exhibition>(predicate: #Predicate { $0.id == id })
                    guard let exhibition = try context.fetch(descriptor).first else {
                        cancelEndingSoonNotifications(exhibitionID: id)
                        return
                    }
                    let settings = settingsStore.endingSoonNotificationSettings
                    let lastAttempt = (defaults.dictionary(forKey: attemptsKey)?[id] as? Double) ?? 0
                    // OFFの解除は待たせず、予約の連続失敗だけを抑制する。
                    guard !settings.isEnabled || clock().timeIntervalSince1970 - lastAttempt >= retryInterval else { return }
                    await schedule(exhibition: exhibition, isEnabled: settings.isEnabled, time: settings.notificationTime)
                } catch {
                    logger.error("期限通知の再試行用データ取得に失敗: \(error.localizedDescription, privacy: .private)")
                }
            }
        }
        for task in tasks { await task.value }
    }

    /// 旧バージョンの時間帯指定なしの予約も、初回の起動・復帰時に日本時間へ更新する。
    private func migrateNotificationTimeZoneIfNeeded(in context: ModelContext) async {
        let key = "endingSoonNotificationsUseJapanTimeZone"
        guard !defaults.bool(forKey: key), !isMigratingTimeZone else { return }
        isMigratingTimeZone = true
        defer { isMigratingTimeZone = false }
        do {
            let exhibitions = try context.fetch(FetchDescriptor<Exhibition>())
            let settings = settingsStore.endingSoonNotificationSettings
            await rescheduleAllNotifications(
                exhibitions: exhibitions,
                isEnabled: settings.isEnabled,
                notificationTime: settings.notificationTime
            )
            // 予約失敗分は既存の再試行対象に残る。
            defaults.set(true, forKey: key)
        } catch {
            logger.error("通知の時間帯更新用データ取得に失敗: \(error.localizedDescription, privacy: .private)")
        }
    }

    /// 対象IDを永続化してから一列に実行する。同じIDの古い処理は最新の依頼で無効になる。
    private func enqueue(exhibitionID: String, operation: @escaping @MainActor () async -> Void) -> Task<Void, Never> {
        pendingIDs.insert(exhibitionID)
        let revision = UUID()
        revisions[exhibitionID] = revision
        queuedIDs.insert(exhibitionID)
        let previous = tail
        let task = Task { @MainActor [self] in
            await previous?.value
            guard revisions[exhibitionID] == revision else { return }
            await operation()
            if revisions[exhibitionID] == revision {
                queuedIDs.remove(exhibitionID)
            }
        }
        tail = task
        return task
    }

    /// 設定時刻まで組み立てた未来の通知だけを予約する。権限不足は保留し、失敗はログへ記録する。
    private func schedule(exhibition: Exhibition, isEnabled: Bool, time: DateComponents) async {
        let id = exhibition.id
        let revision = revisions[id]
        let identifiers = endingSoonNotificationIDs(for: id)
        client.removePending(identifiers)
        guard isEnabled else { finish(id); return }

        let calendar = Calendar.japan
        let hasFutureNotification = Self.endingSoonReminders.contains {
            notificationDate(endDate: exhibition.endDate, daysBefore: $0.daysBefore, time: time, calendar: calendar) != nil
        }
        guard hasFutureNotification else { finish(id); return }
        let status = await client.authorizationStatus()
        guard revisions[id] == revision else { return }
        guard canSchedule(status) else { return }

        var attempts = defaults.dictionary(forKey: attemptsKey) ?? [:]
        attempts[id] = clock().timeIntervalSince1970
        defaults.set(attempts, forKey: attemptsKey)
        var failed = false
        for reminder in Self.endingSoonReminders {
            guard let date = notificationDate(
                endDate: exhibition.endDate, daysBefore: reminder.daysBefore,
                time: time, calendar: calendar
            ) else { continue }

            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = "\(exhibition.title) @ \(exhibition.venue)"
            content.sound = .default
            let request = UNNotificationRequest(
                identifier: "d\(reminder.daysBefore)_\(id)", content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: date, repeats: false)
            )
            do {
                try await client.add(request)
            } catch {
                failed = true
                logger.error("期限通知の予約に失敗。次回再試行します: \(error.localizedDescription, privacy: .private)")
            }
            // await中の削除・設定変更後に古い通知を残さない。次の依頼はこの処理の後で実行される。
            guard revisions[id] == revision else {
                client.removePending(identifiers)
                return
            }
        }
        if !failed { finish(id) }
    }

    /// 終了日から指定日数を引き、設定時刻を反映した日時が未来の場合だけ返す。
    private func notificationDate(endDate: Date, daysBefore: Int, time: DateComponents, calendar: Calendar) -> DateComponents? {
        guard let day = calendar.date(byAdding: .day, value: -daysBefore, to: endDate) else { return nil }
        var date = calendar.dateComponents([.year, .month, .day], from: day)
        date.calendar = calendar
        date.timeZone = calendar.timeZone
        date.hour = time.hour ?? 9
        date.minute = time.minute ?? 0
        guard let scheduledDate = calendar.date(from: date), scheduledDate > clock() else { return nil }
        return date
    }

    /// 成功・OFF・削除・期限切れで再試行が不要になったIDと試行時刻を消す。
    private func finish(_ id: String) {
        pendingIDs.remove(id)
        var attempts = defaults.dictionary(forKey: attemptsKey) ?? [:]
        attempts.removeValue(forKey: id)
        defaults.set(attempts, forKey: attemptsKey)
    }

    /// 近隣通知を1秒後に予約し、成功した場合だけtrueを返す。失敗した内容は後から再送しない。
    /// 距離・開館状況・通知頻度は呼び出し元が最新の条件で判定する。
    func scheduleNearbyOpenNotification(for exhibition: Exhibition, identifier: String) async -> Bool {
        let status = await client.authorizationStatus()
        guard canSchedule(status) else { return false }
        // 許可待ちは失敗として数えず、実際の予約エラーだけを間引く。
        if let lastNearbyFailure, clock().timeIntervalSince(lastNearbyFailure) < retryInterval { return false }
        let content = UNMutableNotificationContent()
        content.title = "近くで開館中の展示があります"
        content.body = "\(exhibition.title) @ \(exhibition.venue)"
        content.sound = .default
        let req = UNNotificationRequest(identifier: identifier, content: content, trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false))
        do {
            try await client.add(req)
            lastNearbyFailure = nil
            return true
        } catch {
            lastNearbyFailure = clock()
            logger.error("近隣通知の予約に失敗。次の判定機会に再評価します: \(error.localizedDescription, privacy: .private)")
            return false
        }
    }
}
