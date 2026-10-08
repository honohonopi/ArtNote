import CoreGraphics
import Foundation

/// 1日分の予定と提案を、タイムライン上の表示位置へ変換する。
struct DayTimelineLayoutBuilder {
    struct Metrics {
        let timeColumnWidth: CGFloat
        let hourHeight: CGFloat
        let columnSpacing: CGFloat
        let horizontalPadding: CGFloat
        let timeToEventSpacing: CGFloat
        let suggestionCarouselPadding: CGFloat

        init(
            timeColumnWidth: CGFloat = 44,
            hourHeight: CGFloat = 60,
            columnSpacing: CGFloat = 6,
            horizontalPadding: CGFloat = 8,
            timeToEventSpacing: CGFloat = 8,
            suggestionCarouselPadding: CGFloat = 16
        ) {
            self.timeColumnWidth = timeColumnWidth
            self.hourHeight = hourHeight
            self.columnSpacing = columnSpacing
            self.horizontalPadding = horizontalPadding
            self.timeToEventSpacing = timeToEventSpacing
            self.suggestionCarouselPadding = suggestionCarouselPadding
        }

        var dayHeight: CGFloat { hourHeight * 24 }
    }

    struct Layout {
        let events: [EventItem]
        let suggestionClusters: [SuggestionCluster]
    }

    struct EventItem: Identifiable {
        let event: DayTimelineEvent
        let column: Int
        let columnCount: Int
        let yOffset: CGFloat
        let height: CGFloat

        var id: String { event.id }
    }

    struct SuggestionItem: Identifiable {
        let suggestion: TimelineSuggestion
        let column: Int
        let columnCount: Int
        let yOffset: CGFloat
        let relativeYOffset: CGFloat
        let height: CGFloat

        var id: String { suggestion.id }
    }

    struct SuggestionCluster: Identifiable {
        let items: [SuggestionItem]
        let columnCount: Int
        let yOffset: CGFloat
        let height: CGFloat
        let start: Date
        let end: Date

        var id: String {
            let startValue = Int(start.timeIntervalSince1970)
            let endValue = Int(end.timeIntervalSince1970)
            return "\(startValue)-\(endValue)-\(items.count)"
        }
    }

    let metrics: Metrics
    private let dayStart: Date
    private let dayEnd: Date

    init(day: Date, metrics: Metrics = Metrics()) {
        self.metrics = metrics
        dayStart = Calendar.japan.startOfDay(for: day)
        dayEnd = Calendar.japan.date(byAdding: .day, value: 1, to: dayStart) ?? day
    }

    func build(
        events: [DayTimelineEvent],
        suggestions: [TimelineSuggestion]
    ) -> Layout {
        Layout(
            events: buildEvents(events),
            suggestionClusters: buildSuggestionClusters(suggestions)
        )
    }

    func itemWidth(in totalWidth: CGFloat, columns: Int) -> CGFloat {
        let contentWidth = max(
            0,
            totalWidth - metrics.timeColumnWidth - metrics.timeToEventSpacing - metrics.horizontalPadding * 2
        )
        let spacing = CGFloat(max(columns - 1, 0)) * metrics.columnSpacing
        return (contentWidth - spacing) / CGFloat(max(columns, 1))
    }

    func itemXOffset(in totalWidth: CGFloat, column: Int, columns: Int) -> CGFloat {
        CGFloat(column) * (itemWidth(in: totalWidth, columns: columns) + metrics.columnSpacing)
    }

    func carouselXOffset(column: Int, cardWidth: CGFloat) -> CGFloat {
        CGFloat(column) * (cardWidth + metrics.columnSpacing)
    }

    func carouselContentWidth(columns: Int, cardWidth: CGFloat) -> CGFloat {
        guard columns > 0 else { return 0 }
        return CGFloat(columns) * cardWidth + CGFloat(columns - 1) * metrics.columnSpacing
    }

    private func buildEvents(_ events: [DayTimelineEvent]) -> [EventItem] {
        TimelineLayout.clusters(for: events, start: \.startDate, end: \.endDate).flatMap { cluster in
            cluster.items.map { item in
                let start = max(item.value.startDate, dayStart)
                let end = min(item.value.endDate, dayEnd)
                return EventItem(
                    event: item.value,
                    column: item.column,
                    columnCount: cluster.columnCount,
                    yOffset: yOffset(for: start),
                    height: max(24, height(forMinutes: max(30, minutesBetween(start, end))))
                )
            }
        }
    }

    private func buildSuggestionClusters(_ suggestions: [TimelineSuggestion]) -> [SuggestionCluster] {
        TimelineLayout.clusters(
            for: suggestions,
            start: \.availableStart,
            end: \.availableEnd
        ).map { cluster in
            let items = cluster.items.map { item in
                let start = max(item.value.availableStart, dayStart)
                let end = min(item.value.availableEnd, dayEnd)
                return SuggestionItem(
                    suggestion: item.value,
                    column: item.column,
                    columnCount: cluster.columnCount,
                    yOffset: yOffset(for: start),
                    relativeYOffset: height(forMinutes: minutesBetween(cluster.start, max(item.value.availableStart, cluster.start))),
                    height: height(forMinutes: minutesBetween(start, end))
                )
            }
            return SuggestionCluster(
                items: items,
                columnCount: cluster.columnCount,
                yOffset: yOffset(for: cluster.start),
                height: height(forMinutes: minutesBetween(cluster.start, cluster.end)),
                start: cluster.start,
                end: cluster.end
            )
        }
    }

    private func yOffset(for date: Date) -> CGFloat {
        let components = Calendar.japan.dateComponents([.hour, .minute], from: date)
        let minutes = Double(components.hour ?? 0) * 60 + Double(components.minute ?? 0)
        return height(forMinutes: max(0, minutes))
    }

    private func height(forMinutes minutes: Double) -> CGFloat {
        CGFloat(max(0, minutes) / 60) * metrics.hourHeight
    }

    private func minutesBetween(_ start: Date, _ end: Date) -> Double {
        max(0, end.timeIntervalSince(start) / 60)
    }
}
