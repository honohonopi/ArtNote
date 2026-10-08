import SwiftUI

struct ScheduleEditorListView: View {
    @Binding var scheduleOpenTime: String?
    @Binding var scheduleCloseTime: String?
    @Binding var scheduleLastEntryTime: String?
    @Binding var scheduleClosedWeekdays: [Weekday]
    @Binding var scheduleHolidayHandling: HolidayHandling?
    @Binding var scheduleClosedDateRules: [DateRule]
    @Binding var scheduleOpenDateRules: [DateRule]
    @Binding var scheduleSpecialOpenings: [SpecialOpening]
    let onAddSpecialOpening: () -> Void
    let onEditSpecialOpening: (Int) -> Void

    var body: some View {
        Group {
            HStack {
                Text("開館時間")
                Spacer()
                HStack(spacing: 4) {
                    DatePicker("", selection: $scheduleOpenTime.timePickerDate(defaultTime: "10:00"), displayedComponents: .hourAndMinute)
                        .labelsHidden()
                    Text("〜")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 16)
                    DatePicker("", selection: $scheduleCloseTime.timePickerDate(defaultTime: "17:00"), displayedComponents: .hourAndMinute)
                        .labelsHidden()
                }
            }
            HStack {
                Text("最終入場")
                Spacer()
                if scheduleLastEntryTime != nil {
                    HStack(spacing: 8) {
                        DatePicker("", selection: $scheduleLastEntryTime.timePickerDate(defaultTime: scheduleCloseTime ?? "17:00"), displayedComponents: .hourAndMinute)
                            .labelsHidden()
                        Button {
                            scheduleLastEntryTime = nil
                        } label: {
                            Image(systemName: "minus.circle")
                                .foregroundStyle(.red)
                        }
                    }
                } else {
                    HStack(spacing: 6) {
                        Text("未設定")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Button {
                            scheduleLastEntryTime = scheduleCloseTime ?? "17:00"
                        } label: {
                            Image(systemName: "plus.circle")
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            HStack {
                Text("休館曜日")
                Spacer()
                HStack(spacing: 6) {
                    ForEach(Weekday.allCases, id: \.self) { day in
                        let selected = scheduleClosedWeekdays.contains(day)
                        Button(day.shortDisplayName) {
                            toggleWeekday(day)
                        }
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(selected ? Color.blue.opacity(0.2) : Color(.systemGray5))
                        .clipShape(Capsule())
                        .buttonStyle(.plain)
                    }
                }
            }
            HStack {
                Text("祝日対応")
                Spacer()
                Menu {
                    Button("記載なし") { scheduleHolidayHandling = nil }
                    Button("祝日対応なし") { scheduleHolidayHandling = HolidayHandling.none }
                    Button("祝日は開館") { scheduleHolidayHandling = HolidayHandling.openOnHoliday }
                    Button("祝日開館、翌平日休館") { scheduleHolidayHandling = HolidayHandling.openOnHolidayCloseNextWeekday }
                } label: {
                    HStack(spacing: 6) {
                        Text(scheduleHolidayHandling?.displayName ?? "記載なし")
                            .foregroundStyle(.black)
                        Image(systemName: "chevron.up.chevron.down")
                            .foregroundStyle(.blue)
                            .font(.caption)
                    }
                }
            }
            HStack {
                Text("特別休館日")
                Spacer()
                Menu {
                    Button("単日") {
                        scheduleClosedDateRules.append(DateRule(rule: .date(Date()), note: nil))
                    }
                    Button("期間") {
                        let start = Date()
                        let end = Calendar.japan.date(byAdding: .day, value: 1, to: start) ?? start
                        scheduleClosedDateRules.append(DateRule(rule: .range(start: start, end: end), note: nil))
                    }
                } label: {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(.blue)
                }
            }
            ForEach(scheduleClosedDateRules.indices, id: \.self) { idx in
                HStack {
                    Spacer()
                    switch scheduleClosedDateRules[idx].rule {
                    case .date(let date):
                        DatePicker("", selection: Binding(
                            get: { date },
                            set: { newDate in
                                scheduleClosedDateRules[idx].rule = .date(newDate)
                            }
                        ), displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                    case .range(let start, let end):
                        DatePicker("", selection: Binding(
                            get: { start },
                            set: { newStart in
                                scheduleClosedDateRules[idx].rule = .range(start: newStart, end: end)
                            }
                        ), displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                        Text("〜")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        DatePicker("", selection: Binding(
                            get: { end },
                            set: { newEnd in
                                scheduleClosedDateRules[idx].rule = .range(start: start, end: newEnd)
                            }
                        ), displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                    }
                    Button {
                        scheduleClosedDateRules.remove(at: idx)
                    } label: {
                        Image(systemName: "minus.circle")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
                .environment(\.locale, Locale(identifier: "ja_JP"))
                .environment(\.calendar, Calendar.japan)
            }
            HStack {
                Text("特別開館日")
                Spacer()
                Button {
                    scheduleOpenDateRules.append(DateRule(rule: .date(Date()), note: nil))
                } label: {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(.blue)
                }
            }
            ForEach(scheduleOpenDateRules.indices, id: \.self) { idx in
                HStack {
                    Spacer()
                    DatePicker("", selection: Binding(
                        get: {
                            if case .date(let date) = scheduleOpenDateRules[idx].rule {
                                return date
                            }
                            return Date()
                        },
                        set: { newDate in
                            scheduleOpenDateRules[idx].rule = .date(newDate)
                        }
                    ), displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    Button {
                        scheduleOpenDateRules.remove(at: idx)
                    } label: {
                        Image(systemName: "minus.circle")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
                .environment(\.locale, Locale(identifier: "ja_JP"))
                .environment(\.calendar, Calendar.japan)
            }
            HStack {
                Text("特別開館時間")
                Spacer()
                Button(action: onAddSpecialOpening) {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }
            ForEach(scheduleSpecialOpenings.indices, id: \.self) { idx in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(scheduleSpecialOpenings[idx].displayLabel)
                            .foregroundStyle(.primary)
                        Spacer()
                        Text("\(scheduleSpecialOpenings[idx].openTime)〜\(scheduleSpecialOpenings[idx].closeTime)")
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                        Menu {
                            Button("編集") { onEditSpecialOpening(idx) }
                            Button("削除", role: .destructive) {
                                scheduleSpecialOpenings.remove(at: idx)
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .foregroundStyle(.blue)
                        }
                    }
                    if let last = scheduleSpecialOpenings[idx].lastEntryTime, !last.isEmpty {
                        Text("最終入場 \(last)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func toggleWeekday(_ weekday: Weekday) {
        if let idx = scheduleClosedWeekdays.firstIndex(of: weekday) {
            scheduleClosedWeekdays.remove(at: idx)
        } else {
            scheduleClosedWeekdays.append(weekday)
            scheduleClosedWeekdays.sort { $0.calendarValue < $1.calendarValue }
        }
    }

}
