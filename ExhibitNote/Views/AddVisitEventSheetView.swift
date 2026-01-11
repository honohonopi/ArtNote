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
                    DatePicker(
                        "訪問日",
                        selection: $visitDate,
                        displayedComponents: [.date]
                    )
                    .datePickerStyle(.compact)
                    .environment(\.locale, Locale(identifier: "ja_JP"))
                    .environment(\.calendar, Calendar(identifier: .gregorian))
                    .environment(\.timeZone, TimeZone(identifier: "Asia/Tokyo")!)
                    DatePicker(
                        "開始",
                        selection: $startTime,
                        displayedComponents: [.hourAndMinute]
                    )
                    DatePicker(
                        "終了",
                        selection: $endTime,
                        displayedComponents: [.hourAndMinute]
                    )
                }
                if let availableEnd {
                    Section {
                        Text("空き時間: \(timeRangeText(start: composedStartDate, end: availableEnd))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
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
                let start = merge(date: visitDate, time: newValue, calendar: .init(identifier: .gregorian))
                let end = merge(date: visitDate, time: endTime, calendar: .init(identifier: .gregorian))
                startTime = start
                if end < start {
                    endTime = start.addingTimeInterval(30 * 60)
                }
            }
            .onChange(of: endTime) { _, newValue in
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

    private var composedStartDate: Date {
        merge(date: visitDate, time: startTime, calendar: .init(identifier: .gregorian))
    }

    private var composedEndDate: Date {
        merge(date: visitDate, time: endTime, calendar: .init(identifier: .gregorian))
    }

    private func addEvent() async {
        do {
            let granted = try await EventKitService.shared.requestAccess()
            guard granted else {
                errorMessage = "カレンダーへのアクセスが許可されていません"
                return
            }
            try EventKitService.shared.addVisitEvent(
                exhibition: exhibition,
                startDate: composedStartDate,
                endDate: composedEndDate
            )
            addedStartDate = composedStartDate
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
