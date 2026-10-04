//
//  AddVisitEventSheetView.swift
//  ExhibitNote
//
//  Created by Codex on 2026/01/xx.
//

import SwiftUI
import UIKit

struct AddVisitEventSheetView: View {
    let exhibition: Exhibition
    let initialStart: Date
    let availableEnd: Date?

    @Environment(\.dismiss) private var dismiss
    @State private var visitDate: Date
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var showSuccess = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var addedStartDate: Date?

    init(exhibition: Exhibition, initialStart: Date, availableEnd: Date? = nil) {
        self.exhibition = exhibition
        self.initialStart = initialStart
        self.availableEnd = availableEnd
        let calendar = Calendar(identifier: .gregorian)
        let twoHoursLater = initialStart.addingTimeInterval(2 * 3600)
        let cappedEnd = availableEnd.map { min($0, twoHoursLater) } ?? twoHoursLater
        _visitDate = State(initialValue: calendar.startOfDay(for: initialStart))
        _startTime = State(initialValue: initialStart)
        _endTime = State(initialValue: cappedEnd)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Apple純正カレンダーに予定を追加できます。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("訪問日時") {
                    if availableEnd != nil {
                        LabeledContent("訪問日") {
                            Text(initialStart, format: .dateTime.year().month().day())
                        }
                    } else {
                        DatePicker(
                            "訪問日",
                            selection: $visitDate,
                            displayedComponents: [.date]
                        )
                        .datePickerStyle(.compact)
                        .environment(\.locale, Locale(identifier: "ja_JP"))
                        .environment(\.calendar, Calendar(identifier: .gregorian))
                        .environment(\.timeZone, TimeZone(identifier: "Asia/Tokyo")!)
                    }
                    DatePicker(
                        "開始",
                        selection: $startTime,
                        in: startTimeRange,
                        displayedComponents: [.hourAndMinute]
                    )
                    DatePicker(
                        "終了",
                        selection: $endTime,
                        in: endTimeRange,
                        displayedComponents: [.hourAndMinute]
                    )
                }
                if let availableEnd {
                    Section {
                        Text("空き時間: \(timeRangeText(start: initialStart, end: availableEnd))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Text("この空き時間の範囲内で、開始・終了時刻を選べます。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .disabled(isSaving)
            .navigationTitle("予定に追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") {
                        Task { await addEvent() }
                    }
                    .disabled(isSaving || !canSave)
                }
            }
            .onChange(of: visitDate) { _, newValue in
                let calendar = Calendar(identifier: .gregorian)
                let start = merge(date: newValue, time: startTime, calendar: calendar)
                let end = merge(date: newValue, time: endTime, calendar: calendar)
                startTime = start
                endTime = max(end, start.addingTimeInterval(30 * 60))
            }
            .onChange(of: startTime) { _, newValue in
                if let availableEnd {
                    if endTime <= newValue {
                        endTime = min(newValue.addingTimeInterval(30 * 60), availableEnd)
                    }
                    return
                }
                let start = merge(date: visitDate, time: newValue, calendar: .init(identifier: .gregorian))
                let end = merge(date: visitDate, time: endTime, calendar: .init(identifier: .gregorian))
                startTime = start
                if end < start {
                    endTime = start.addingTimeInterval(30 * 60)
                }
            }
            .onChange(of: endTime) { _, newValue in
                guard availableEnd == nil else { return }
                let end = merge(date: visitDate, time: newValue, calendar: .init(identifier: .gregorian))
                let start = merge(date: visitDate, time: startTime, calendar: .init(identifier: .gregorian))
                endTime = max(end, start)
            }
            .alert("カレンダーに追加しました", isPresented: $showSuccess) {
                Button("OK") { dismiss() }
                Button("純正カレンダーで見る") {
                    if let target = addedStartDate {
                        openCalendar(at: target)
                    }
                    dismiss()
                }
            } message: {
                Text("純正カレンダーで確認できます")
            }
            .alert("予定の追加に失敗しました", isPresented: Binding(get: {
                errorMessage != nil
            }, set: { newValue in
                if !newValue { errorMessage = nil }
            })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var startTimeRange: ClosedRange<Date> {
        guard let availableEnd else { return .distantPast ... .distantFuture }
        // 分単位の入力で、終了より前の時刻だけを開始として選べるようにする。
        return initialStart ... max(initialStart, availableEnd.addingTimeInterval(-60))
    }

    private var endTimeRange: ClosedRange<Date> {
        guard let availableEnd else { return .distantPast ... .distantFuture }
        return min(max(initialStart, startTime.addingTimeInterval(60)), availableEnd) ... availableEnd
    }

    private var composedStartDate: Date {
        if availableEnd != nil { return startTime }
        return merge(date: visitDate, time: startTime, calendar: .init(identifier: .gregorian))
    }

    private var composedEndDate: Date {
        if availableEnd != nil { return endTime }
        return merge(date: visitDate, time: endTime, calendar: .init(identifier: .gregorian))
    }

    private var canSave: Bool {
        guard composedEndDate > composedStartDate else { return false }
        guard let availableEnd else { return true }
        return composedStartDate >= initialStart && composedEndDate <= availableEnd
    }

    private func addEvent() async {
        guard !isSaving else { return }
        guard canSave else {
            errorMessage = "終了は開始より後にし、提案された空き時間の範囲内で選んでください。"
            return
        }
        let start = composedStartDate
        let end = composedEndDate
        isSaving = true
        defer { isSaving = false }
        do {
            let granted = try await EventKitService.shared.requestAccess()
            guard granted else {
                errorMessage = "カレンダーへのアクセスが許可されていません"
                return
            }
            try EventKitService.shared.addVisitEvent(
                exhibition: exhibition,
                startDate: start,
                endDate: end
            )
            addedStartDate = start
            showSuccess = true
        } catch {
            errorMessage = "カレンダーの追加に失敗しました"
        }
    }

    private func timeRangeText(start: Date, end: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "ja_JP")
        df.dateFormat = "HH:mm"
        return "\(df.string(from: start))–\(df.string(from: end))"
    }

    private func merge(date: Date, time: Date, calendar: Calendar) -> Date {
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
        var components = DateComponents()
        components.year = dateComponents.year
        components.month = dateComponents.month
        components.day = dateComponents.day
        components.hour = timeComponents.hour
        components.minute = timeComponents.minute
        return calendar.date(from: components) ?? date
    }

    private func openCalendar(at date: Date) {
        let seconds = date.timeIntervalSinceReferenceDate
        if let url = URL(string: "calshow:\(seconds)") {
            UIApplication.shared.open(url)
        }
    }
}
