import SwiftUI

struct SpecialOpeningEditorSheetView: View {
    @Binding var editingSpecialOpeningIndex: Int?
    @Binding var showSpecialOpeningEditor: Bool
    @Binding var specialOpeningMode: SpecialOpeningInputMode
    @Binding var draftSpecialOpeningDate: Date
    @Binding var draftSpecialOpeningStartDate: Date
    @Binding var draftSpecialOpeningEndDate: Date
    @Binding var draftSpecialOpeningWeekdays: Set<Weekday>
    @Binding var draftSpecialOpeningOpenTime: String
    @Binding var draftSpecialOpeningCloseTime: String
    @Binding var draftSpecialOpeningLastEntryTime: String?
    let onToggleWeekday: (Weekday) -> Void
    let onCommit: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("種別") {
                    Picker("種別", selection: $specialOpeningMode) {
                        ForEach(SpecialOpeningInputMode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Section("対象") {
                    switch specialOpeningMode {
                    case .date:
                        DatePicker("日付", selection: $draftSpecialOpeningDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                    case .weekday:
                        HStack(spacing: 6) {
                            ForEach(Weekday.allCases, id: \.self) { day in
                                let selected = draftSpecialOpeningWeekdays.contains(day)
                                Button(day.shortDisplayName) {
                                    onToggleWeekday(day)
                                }
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                                .background(selected ? Color.blue.opacity(0.2) : Color(.systemGray5))
                                .clipShape(Capsule())
                                .buttonStyle(.plain)
                            }
                        }
                    case .range:
                        DatePicker("開始日", selection: $draftSpecialOpeningStartDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                        DatePicker("終了日", selection: $draftSpecialOpeningEndDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                    }
                }
                Section("時間") {
                    HStack {
                        Text("開館")
                        Spacer()
                        DatePicker("", selection: $draftSpecialOpeningOpenTime.timePickerDate(defaultTime: "10:00"), displayedComponents: .hourAndMinute)
                            .labelsHidden()
                    }
                    HStack {
                        Text("閉館")
                        Spacer()
                        DatePicker("", selection: $draftSpecialOpeningCloseTime.timePickerDate(defaultTime: "17:00"), displayedComponents: .hourAndMinute)
                            .labelsHidden()
                    }
                    HStack {
                        Text("最終入場")
                        Spacer()
                        if draftSpecialOpeningLastEntryTime != nil {
                            HStack(spacing: 8) {
                                DatePicker("", selection: $draftSpecialOpeningLastEntryTime.timePickerDate(defaultTime: draftSpecialOpeningCloseTime), displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                                Button {
                                    draftSpecialOpeningLastEntryTime = nil
                                } label: {
                                    Image(systemName: "minus.circle")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        } else {
                            HStack(spacing: 6) {
                                Text("未設定")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Button {
                                    draftSpecialOpeningLastEntryTime = draftSpecialOpeningCloseTime
                                } label: {
                                    Image(systemName: "plus.circle")
                                        .foregroundStyle(.blue)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .navigationTitle(editingSpecialOpeningIndex == nil ? "特別開館時間" : "特別開館時間を編集")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        editingSpecialOpeningIndex = nil
                        showSpecialOpeningEditor = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(editingSpecialOpeningIndex == nil ? "追加" : "保存") {
                        onCommit()
                        showSpecialOpeningEditor = false
                    }
                    .disabled(specialOpeningMode == .weekday && draftSpecialOpeningWeekdays.isEmpty)
                }
            }
        }
        .environment(\.locale, Locale(identifier: "ja_JP"))
        .environment(\.calendar, Calendar.japan)
    }

}
