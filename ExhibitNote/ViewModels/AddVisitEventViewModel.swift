import Foundation
import Observation
import EventKit

@MainActor
@Observable
final class AddVisitEventViewModel {
    let initialStart: Date
    let availableEnd: Date?

    private(set) var visitDate: Date
    private(set) var startTime: Date
    private(set) var endTime: Date
    private(set) var isSaving = false
    private(set) var errorMessage: String?
    private(set) var shouldOpenCalendarSettings = false
    private(set) var addedStartDate: Date?
    var showSuccess = false

    private let exhibition: Exhibition
    private let eventService: any VisitEventSaving
    private let calendar: Calendar

    init(
        exhibition: Exhibition,
        initialStart: Date,
        availableEnd: Date? = nil,
        eventService: (any VisitEventSaving)? = nil,
        calendar: Calendar = Calendar.japan
    ) {
        self.exhibition = exhibition
        self.initialStart = initialStart
        self.availableEnd = availableEnd
        self.eventService = eventService ?? EventKitService.shared
        self.calendar = calendar
        self.visitDate = calendar.startOfDay(for: initialStart)
        self.startTime = initialStart
        let twoHoursLater = initialStart.addingTimeInterval(2 * 3600)
        self.endTime = availableEnd.map { min($0, twoHoursLater) } ?? twoHoursLater
    }

    var startTimeRange: ClosedRange<Date> {
        guard let availableEnd else { return .distantPast ... .distantFuture }
        return initialStart ... max(initialStart, availableEnd.addingTimeInterval(-60))
    }

    var endTimeRange: ClosedRange<Date> {
        guard let availableEnd else { return .distantPast ... .distantFuture }
        return min(max(initialStart, startTime.addingTimeInterval(60)), availableEnd) ... availableEnd
    }

    var canSave: Bool {
        !isSaving && addedStartDate == nil && hasValidDates
    }

    /// 提案から開いた場合は訪問日を固定する。
    func updateVisitDate(_ date: Date) {
        guard !isSaving, addedStartDate == nil, availableEnd == nil else { return }
        visitDate = calendar.startOfDay(for: date)
        let start = merge(date: visitDate, time: startTime)
        let end = merge(date: visitDate, time: endTime)
        startTime = start
        endTime = max(end, start.addingTimeInterval(30 * 60))
    }

    func updateStartTime(_ time: Date) {
        guard !isSaving, addedStartDate == nil else { return }
        if let availableEnd {
            startTime = min(max(time, startTimeRange.lowerBound), startTimeRange.upperBound)
            if endTime <= startTime {
                endTime = min(startTime.addingTimeInterval(30 * 60), availableEnd)
            }
        } else {
            startTime = merge(date: visitDate, time: time)
            if endTime < startTime {
                endTime = startTime.addingTimeInterval(30 * 60)
            }
        }
    }

    func updateEndTime(_ time: Date) {
        guard !isSaving, addedStartDate == nil else { return }
        if availableEnd != nil {
            endTime = min(max(time, endTimeRange.lowerBound), endTimeRange.upperBound)
        } else {
            endTime = max(merge(date: visitDate, time: time), composedStartDate)
        }
    }

    /// 許可確認中の連打と、保存成功後の再追加を防ぐ。
    func addEvent() async {
        guard !isSaving, addedStartDate == nil else { return }
        guard hasValidDates else {
            errorMessage = availableEnd == nil
                ? "終了時刻は開始時刻より後にしてください。"
                : "終了は開始より後にし、提案された空き時間の範囲内で選んでください。"
            return
        }
        let start = composedStartDate
        let end = composedEndDate
        isSaving = true
        clearError()
        defer { isSaving = false }
        do {
            let status = eventService.authorizationStatus()
            if status == .denied || status == .restricted {
                showAccessError(status)
                return
            }
            let granted = try await eventService.requestAccess()
            guard granted else {
                showAccessError(eventService.authorizationStatus())
                return
            }
            try eventService.addVisitEvent(exhibition: exhibition, startDate: start, endDate: end, notes: nil)
            addedStartDate = start
            showSuccess = true
        } catch {
            let status = eventService.authorizationStatus()
            if status == .denied || status == .restricted {
                showAccessError(status)
            } else {
                errorMessage = "カレンダーの追加に失敗しました"
            }
        }
    }

    func clearError() {
        errorMessage = nil
        shouldOpenCalendarSettings = false
    }

    private func showAccessError(_ status: EKAuthorizationStatus) {
        shouldOpenCalendarSettings = status == .denied
        if status == .restricted {
            errorMessage = "端末の機能制限により、カレンダーを利用できません。スクリーンタイムや管理者による制限を確認してください。"
        } else if status == .denied {
            errorMessage = "カレンダーへのアクセスが許可されていません。設定アプリで、このアプリのカレンダーへのアクセスを許可してください。"
        } else {
            errorMessage = "カレンダーへのアクセス許可を確認できませんでした。もう一度お試しください。"
        }
    }

    private var hasValidDates: Bool {
        guard composedEndDate > composedStartDate else { return false }
        guard let availableEnd else { return true }
        return composedStartDate >= initialStart && composedEndDate <= availableEnd
    }

    private var composedStartDate: Date {
        availableEnd == nil ? merge(date: visitDate, time: startTime) : startTime
    }

    private var composedEndDate: Date {
        availableEnd == nil ? merge(date: visitDate, time: endTime) : endTime
    }

    private func merge(date: Date, time: Date) -> Date {
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
        components.hour = timeComponents.hour
        components.minute = timeComponents.minute
        return calendar.date(from: components) ?? date
    }
}
