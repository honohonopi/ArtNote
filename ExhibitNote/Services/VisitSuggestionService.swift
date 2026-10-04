import Foundation

/// 訪問候補の生成を担当する。
struct VisitSuggestionService {
    private let suggestionBufferMinutes: Double = 30
    private let suggestionMinimumMinutes: Double = 60

    /// 予定の前後30分を避け、開館時間内に60分以上滞在できる候補を返す。
    /// 今日の候補は現在時刻以降に絞り、残り時間で最低滞在時間を判定する。
    func suggestions(
        exhibitions: [Exhibition],
        events: [(start: Date, end: Date)],
        day: Date,
        includeVisited: Bool,
        calendar: Calendar = .japan,
        now: Date = .now
    ) -> [TimelineSuggestion] {
        let dayStart = calendar.startOfDay(for: day)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? day
        let earliestStart = calendar.isDate(day, inSameDayAs: now) ? max(dayStart, now) : dayStart
        let blocked = mergedBlockedIntervals(
            events: events,
            dayStart: dayStart,
            dayEnd: dayEnd
        )
        let freeIntervals = availableIntervals(
            blocked: blocked,
            dayStart: dayStart,
            dayEnd: dayEnd
        )
        var suggestions: [TimelineSuggestion] = []
        for exhibition in exhibitions {
            if !includeVisited, exhibition.visited {
                continue
            }
            guard case let .open(openTime, closeTime, _) = ExhibitionScheduleUtils.openingStatus(
                on: day,
                exhibition: exhibition
            ) else {
                continue
            }
            guard let openStart = timeStringToDate(openTime, on: day, calendar: calendar),
                  let openEnd = timeStringToDate(closeTime, on: day, calendar: calendar),
                  openEnd > openStart
            else {
                continue
            }
            for interval in freeIntervals {
                let start = max(interval.start, openStart, earliestStart)
                let end = min(interval.end, openEnd)
                let minutes = end.timeIntervalSince(start) / 60.0
                if minutes >= suggestionMinimumMinutes {
                    suggestions.append(
                        TimelineSuggestion(
                            exhibition: exhibition,
                            availableStart: start,
                            availableEnd: end
                        )
                    )
                }
            }
        }
        return suggestions.sorted { $0.availableStart < $1.availableStart }
    }

    private func timeStringToDate(
        _ timeString: String,
        on day: Date,
        calendar: Calendar
    ) -> Date? {
        let trimmed = timeString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != "未設定" else { return nil }
        let parts = trimmed.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1])
        else {
            return nil
        }
        let dayStart = calendar.startOfDay(for: day)
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: dayStart)
    }

    /// 予定を前後に広げ、日付内に収めて重複する時間帯をまとめる。
    private func mergedBlockedIntervals(
        events: [(start: Date, end: Date)],
        dayStart: Date,
        dayEnd: Date
    ) -> [TimeIntervalRange] {
        let buffered = events.map { event -> TimeIntervalRange in
            let start = event.start.addingTimeInterval(-suggestionBufferMinutes * 60)
            let end = event.end.addingTimeInterval(suggestionBufferMinutes * 60)
            return TimeIntervalRange(
                start: max(start, dayStart),
                end: min(end, dayEnd)
            )
        }
        .filter { $0.end > $0.start }
        .sorted { $0.start < $1.start }

        var merged: [TimeIntervalRange] = []
        for interval in buffered {
            if let last = merged.last, interval.start <= last.end {
                merged[merged.count - 1] = TimeIntervalRange(
                    start: last.start,
                    end: max(last.end, interval.end)
                )
            } else {
                merged.append(interval)
            }
        }
        return merged
    }

    /// 予定で埋まった時間帯の間から空き時間を取り出す。
    private func availableIntervals(
        blocked: [TimeIntervalRange],
        dayStart: Date,
        dayEnd: Date
    ) -> [TimeIntervalRange] {
        var free: [TimeIntervalRange] = []
        var cursor = dayStart
        for interval in blocked {
            if interval.start > cursor {
                free.append(TimeIntervalRange(start: cursor, end: interval.start))
            }
            cursor = max(cursor, interval.end)
        }
        if cursor < dayEnd {
            free.append(TimeIntervalRange(start: cursor, end: dayEnd))
        }
        return free
    }

}

private struct TimeIntervalRange {
    let start: Date
    let end: Date
}
