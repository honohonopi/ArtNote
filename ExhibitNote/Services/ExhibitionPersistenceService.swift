import Foundation
import SwiftData

/// Coordinates explicit writes and their notification side effects on the UI context.
@MainActor
struct ExhibitionPersistenceService {
    let context: ModelContext

    func insert(_ exhibition: Exhibition) async throws {
        try commit { context.insert(exhibition) }
        await refreshNotifications(for: exhibition)
    }

    func update(_ exhibition: Exhibition, changes: () throws -> Void) async throws {
        let restore = snapshot(of: exhibition)
        try commit(changes, restoreOnFailure: restore)
        await refreshNotifications(for: exhibition)
    }

    func delete(_ exhibition: Exhibition) throws {
        let id = exhibition.id
        try commit { context.delete(exhibition) }
        ReminderService.shared.cancelDeadlineNotifications(exhibitionID: id)
    }

    private func commit(
        _ changes: () throws -> Void,
        restoreOnFailure: () -> Void = {}
    ) throws {
        // Preserve unrelated pending edits before establishing our rollback boundary.
        // No suspension is allowed between this save, the mutation, and its save.
        context.processPendingChanges()
        if context.hasChanges { try context.save() }
        do {
            try changes()
            try context.save()
        } catch {
            // SwiftData rollback can leave already-observed property values cached.
            restoreOnFailure()
            context.processPendingChanges()
            context.rollback()
            throw error
        }
    }

    private func snapshot(of exhibition: Exhibition) -> () -> Void {
        func capture<Value>(_ keyPath: ReferenceWritableKeyPath<Exhibition, Value>) -> () -> Void {
            let value = exhibition[keyPath: keyPath]
            return { exhibition[keyPath: keyPath] = value }
        }
        let restoreValues = [
            capture(\.title),
            capture(\.venue),
            capture(\.address),
            capture(\.startDate),
            capture(\.endDate),
            capture(\.url),
            capture(\.catalogTotalCount),
            capture(\.colorR),
            capture(\.colorG),
            capture(\.colorB),
            capture(\.latitude),
            capture(\.longitude),
            capture(\.scheduleOpenTime),
            capture(\.scheduleCloseTime),
            capture(\.scheduleLastEntryTime),
            capture(\.scheduleClosedWeekdays),
            capture(\.scheduleHolidayHandling),
            capture(\.scheduleClosedDates),
            capture(\.scheduleOpenDates),
            capture(\.scheduleClosedDateRulesData),
            capture(\.scheduleOpenDateRulesData),
            capture(\.scheduleSpecialOpeningsData),
            capture(\.admissionFeesData),
            capture(\.reservationRequired),
            capture(\.posterThumbData),
            capture(\.posterImageId),
            capture(\.tags),
            capture(\.memoData),
            capture(\.memoUpdatedAt),
            capture(\.catalogImported),
            capture(\.noteCount),
            capture(\.lastViewedNoteIndex),
            capture(\.visited),
            capture(\.visitedAt),
        ]
        return { restoreValues.forEach { $0() } }
    }

    private func refreshNotifications(for exhibition: Exhibition) async {
        let defaults = UserDefaults.standard
        let hour = (defaults.object(forKey: "notifyDeadlineHour") as? Int) ?? 9
        let minute = defaults.integer(forKey: "notifyDeadlineMinute")
        await ReminderService.shared.scheduleDeadlineNotifications(
            for: exhibition,
            isEnabled: defaults.bool(forKey: "notifyDeadlineEnabled"),
            notificationTime: DateComponents(hour: hour, minute: minute)
        )
    }
}
