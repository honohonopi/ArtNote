import Foundation

/// 月間カレンダーの表示に必要な日付と展覧会の帯をまとめたデータ。
struct MonthCalendarData {
    let daysMatrix: [[Date?]]
    let eventSpansBySection: [[EventSpan]]
}

/// 展覧会の会期と開館情報から、月間カレンダーの表示データを生成する。
struct MonthCalendarDataBuilder {
    private let calendar: Calendar

    init(calendar: Calendar = .japan) {
        self.calendar = calendar
    }

    func build(monthAnchor: Date, exhibitions: [Exhibition]) -> MonthCalendarData {
        let daysMatrix = buildDaysMatrix(for: monthAnchor)
        let firstWeekStarts = daysMatrix.map { week in
            let firstDate = week.compactMap { $0 }.first ?? monthAnchor
            return calendar.date(
                from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: firstDate)
            ) ?? monthAnchor
        }

        var eventSpansBySection = Array(repeating: [EventSpan](), count: daysMatrix.count)
        let monthStart = calendar.startOfDay(for: monthAnchor)
        let monthEnd = calendar.date(
            byAdding: DateComponents(month: 1, day: -1),
            to: monthStart
        ) ?? monthStart

        for exhibition in exhibitions {
            let startDate = max(calendar.startOfDay(for: exhibition.startDate), monthStart)
            let endDate = min(calendar.startOfDay(for: exhibition.endDate), monthEnd)
            guard startDate <= endDate else { continue }

            let weekSpans = splitByWeek(
                start: startDate,
                end: endDate
            )
            for weekSpan in weekSpans {
                guard let section = firstWeekStarts.firstIndex(of: weekSpan.weekStart) else { continue }
                eventSpansBySection[section].append(
                    contentsOf: buildEventSpans(for: exhibition, weekSpan: weekSpan)
                )
            }
        }

        for section in eventSpansBySection.indices {
            eventSpansBySection[section] = assignRows(to: eventSpansBySection[section])
        }

        return MonthCalendarData(
            daysMatrix: daysMatrix,
            eventSpansBySection: eventSpansBySection
        )
    }

    private func buildEventSpans(
        for exhibition: Exhibition,
        weekSpan: WeekSpan
    ) -> [EventSpan] {
        var spans: [EventSpan] = []
        var cursor = calendar.startOfDay(for: weekSpan.start)
        let endDate = calendar.startOfDay(for: weekSpan.end)
        var currentStart: Date?
        var currentIsClosed: Bool?

        while cursor <= endDate {
            let isClosed: Bool
            if case .closed = ExhibitionScheduleUtils.openingStatus(
                on: cursor,
                exhibition: exhibition
            ) {
                isClosed = true
            } else {
                isClosed = false
            }

            if currentIsClosed == nil {
                currentStart = cursor
                currentIsClosed = isClosed
            } else if currentIsClosed != isClosed {
                if let startDate = currentStart {
                    let previousDate = calendar.date(
                        byAdding: .day,
                        value: -1,
                        to: cursor
                    ) ?? startDate
                    spans.append(
                        makeSpan(
                            exhibition: exhibition,
                            startDate: startDate,
                            endDate: previousDate,
                            isClosed: currentIsClosed ?? false
                        )
                    )
                }
                currentStart = cursor
                currentIsClosed = isClosed
            }

            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = nextDate
        }

        if let startDate = currentStart, let isClosed = currentIsClosed {
            spans.append(
                makeSpan(
                    exhibition: exhibition,
                    startDate: startDate,
                    endDate: endDate,
                    isClosed: isClosed
                )
            )
        }
        return spans
    }

    private func makeSpan(
        exhibition: Exhibition,
        startDate: Date,
        endDate: Date,
        isClosed: Bool
    ) -> EventSpan {
        EventSpan(
            startColumn: weekdayColumn(for: startDate),
            endColumn: weekdayColumn(for: endDate),
            row: 0,
            title: exhibition.title,
            exhibitionID: exhibition.persistentModelID,
            isClosed: isClosed
        )
    }

    private func assignRows(to spans: [EventSpan]) -> [EventSpan] {
        let orderedSpans = spans.sorted {
            if $0.startColumn != $1.startColumn {
                return $0.startColumn < $1.startColumn
            }
            return ($0.endColumn - $0.startColumn) > ($1.endColumn - $1.startColumn)
        }

        var occupiedRangesByRow: [[ClosedRange<Int>]] = []
        var assignedSpans: [EventSpan] = []

        for span in orderedSpans {
            let range = span.startColumn...span.endColumn
            if let row = occupiedRangesByRow.firstIndex(where: { occupiedRanges in
                !occupiedRanges.contains(where: { $0.overlaps(range) })
            }) {
                occupiedRangesByRow[row].append(range)
                assignedSpans.append(spanWithRow(row, from: span))
            } else {
                occupiedRangesByRow.append([range])
                assignedSpans.append(spanWithRow(occupiedRangesByRow.count - 1, from: span))
            }
        }

        return assignedSpans
    }

    private func spanWithRow(_ row: Int, from span: EventSpan) -> EventSpan {
        EventSpan(
            startColumn: span.startColumn,
            endColumn: span.endColumn,
            row: row,
            title: span.title,
            exhibitionID: span.exhibitionID,
            isClosed: span.isClosed
        )
    }

    private func buildDaysMatrix(for monthAnchor: Date) -> [[Date?]] {
        guard let startOfMonth = calendar.date(
            from: calendar.dateComponents([.year, .month], from: monthAnchor)
        ), let daysInMonth = calendar.range(
            of: .day,
            in: .month,
            for: startOfMonth
        )?.count else {
            return []
        }

        let firstWeekdayIndex = (
            calendar.component(.weekday, from: startOfMonth)
                - calendar.firstWeekday
                + 7
        ) % 7
        var matrix: [[Date?]] = []
        var day = 1
        var firstWeek = Array<Date?>(repeating: nil, count: 7)

        for column in firstWeek.indices where column >= firstWeekdayIndex {
            firstWeek[column] = calendar.date(
                byAdding: .day,
                value: day - 1,
                to: startOfMonth
            )
            day += 1
        }
        matrix.append(firstWeek)

        while day <= daysInMonth {
            var week = Array<Date?>(repeating: nil, count: 7)
            for column in week.indices where day <= daysInMonth {
                week[column] = calendar.date(
                    byAdding: .day,
                    value: day - 1,
                    to: startOfMonth
                )
                day += 1
            }
            matrix.append(week)
        }

        while matrix.count < 6 {
            matrix.append(Array(repeating: nil, count: 7))
        }
        return matrix
    }

    private func splitByWeek(start: Date, end: Date) -> [WeekSpan] {
        var spans: [WeekSpan] = []
        var startDate = calendar.startOfDay(for: start)
        let endDate = calendar.startOfDay(for: end)

        while startDate <= endDate {
            guard let weekStart = calendar.date(
                from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: startDate)
            ), let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) else {
                break
            }

            let spanEnd = min(weekEnd, endDate)
            spans.append(
                WeekSpan(
                    weekStart: weekStart,
                    start: startDate,
                    end: spanEnd
                )
            )
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: spanEnd) else { break }
            startDate = nextDate
        }
        return spans
    }

    private func weekdayColumn(for date: Date) -> Int {
        (calendar.component(.weekday, from: date) - calendar.firstWeekday + 7) % 7
    }
}
