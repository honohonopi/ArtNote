//
//  AddVisitEventSheetView.swift
//  ExhibitNote
//
//  Created by Codex on 2026/01/xx.
//

import SwiftUI
import UIKit

struct AddVisitEventSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var vm: AddVisitEventViewModel

    init(exhibition: Exhibition, initialStart: Date, availableEnd: Date? = nil) {
        _vm = State(initialValue: AddVisitEventViewModel(
            exhibition: exhibition,
            initialStart: initialStart,
            availableEnd: availableEnd
        ))
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
                    if vm.availableEnd != nil {
                        LabeledContent("訪問日") {
                            Text(vm.initialStart.ymdString)
                        }
                    } else {
                        DatePicker(
                            "訪問日",
                            selection: Binding(get: { vm.visitDate }, set: vm.updateVisitDate),
                            displayedComponents: [.date]
                        )
                        .datePickerStyle(.compact)
                        .environment(\.locale, Locale(identifier: "ja_JP"))
                        .environment(\.calendar, Calendar.japan)
                        .environment(\.timeZone, Calendar.japan.timeZone)
                    }
                    DatePicker(
                        "開始",
                        selection: Binding(get: { vm.startTime }, set: vm.updateStartTime),
                        in: vm.startTimeRange,
                        displayedComponents: [.hourAndMinute]
                    )
                    DatePicker(
                        "終了",
                        selection: Binding(get: { vm.endTime }, set: vm.updateEndTime),
                        in: vm.endTimeRange,
                        displayedComponents: [.hourAndMinute]
                    )
                }
                if let availableEnd = vm.availableEnd {
                    Section {
                        Text("空き時間: \(timeRangeText(start: vm.initialStart, end: availableEnd))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Text("この空き時間の範囲内で、開始・終了時刻を選べます。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .disabled(vm.isSaving)
            .navigationTitle("予定に追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                        .disabled(vm.isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") {
                        Task { await vm.addEvent() }
                    }
                    .disabled(!vm.canSave)
                }
            }
            .alert("カレンダーに追加しました", isPresented: $vm.showSuccess) {
                Button("OK") { dismiss() }
                Button("純正カレンダーで見る") {
                    if let target = vm.addedStartDate {
                        openCalendar(at: target)
                    }
                    dismiss()
                }
            } message: {
                Text("純正カレンダーで確認できます")
            }
            .alert("予定の追加に失敗しました", isPresented: Binding(get: {
                vm.errorMessage != nil
            }, set: { newValue in
                if !newValue { vm.clearError() }
            })) {
                if vm.shouldOpenCalendarSettings {
                    Button("設定アプリを開く") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            openURL(url)
                        }
                    }
                }
                Button("OK", role: .cancel) {}
            } message: {
                Text(vm.errorMessage ?? "")
            }
        }
        .interactiveDismissDisabled(vm.isSaving)
        .navigationBarBackButtonHidden(vm.isSaving)
    }

    private func timeRangeText(start: Date, end: Date) -> String {
        let df = DateFormatter.japanese()
        df.locale = Locale(identifier: "ja_JP")
        df.dateFormat = "HH:mm"
        return "\(df.string(from: start))–\(df.string(from: end))"
    }

    private func openCalendar(at date: Date) {
        let seconds = date.timeIntervalSinceReferenceDate
        if let url = URL(string: "calshow:\(seconds)") {
            UIApplication.shared.open(url)
        }
    }
}
