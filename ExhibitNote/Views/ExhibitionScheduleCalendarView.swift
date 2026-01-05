//
//  ExhibitionScheduleCalendarView.swift
//  ArtNote
//
//  Created by Honoka Nishiyama on 2026/01/05.
//

import SwiftUI

final class ExhibitionScheduleCalendarViewModel: ObservableObject {
    @Published var displayedMonth: Date
    @Published var selectedDate: Date?
    @Published var showDaySheet: Bool = false
    
    let exhibition: Exhibition
    private let cal = ExhibitionScheduleUtils.tokyoCalendar
    
    init(exhibition: Exhibition, initialMonth: Date? = nil) {
        self.exhibition = exhibition
        let base = initialMonth ?? exhibition.startDate
        self.displayedMonth = cal.date(from: cal.dateComponents([.year, .month], from: base)) ?? base
    }
    
    func moveMonth(_ offset: Int) {
        guard let next = cal.date(byAdding: .month, value: offset, to: displayedMonth) else { return }
        displayedMonth = next
    }
    
    func monthDates() -> [Date?] {
        guard let range = cal.range(of: .day, in: .month, for: displayedMonth),
              let first = cal.date(from: cal.dateComponents([.year, .month], from: displayedMonth))
        else { return [] }
        
        let firstWeekday = cal.component(.weekday, from: first)
        var days: [Date?] = Array(repeating: nil, count: firstWeekday - 1)
        for day in range {
            if let date = cal.date(byAdding: .day, value: day - 1, to: first) {
                days.append(date)
            }
        }
        while days.count % 7 != 0 {
            days.append(nil)
        }
        return days
    }
    
    func isInPeriod(_ date: Date) -> Bool {
        let day = cal.startOfDay(for: date)
        let start = cal.startOfDay(for: exhibition.startDate)
        let end = cal.startOfDay(for: exhibition.endDate)
        return day >= start && day <= end
    }
}

struct ExhibitionScheduleCalendarView: View {
    @StateObject private var vm: ExhibitionScheduleCalendarViewModel
    private let cal = ExhibitionScheduleUtils.tokyoCalendar
    
    init(exhibition: Exhibition) {
        _vm = StateObject(wrappedValue: ExhibitionScheduleCalendarViewModel(exhibition: exhibition))
    }
    
    var body: some View {
        VStack(spacing: 12) {
            header
            weekdayHeader
            calendarGrid
        }
        .padding()
        .sheet(isPresented: $vm.showDaySheet) {
            if let date = vm.selectedDate {
                ExhibitionDayStatusSheet(date: date, exhibition: vm.exhibition)
            }
        }
    }
    
    private var header: some View {
        HStack {
            Button {
                vm.moveMonth(-1)
            } label: {
                Image(systemName: "chevron.left")
            }
            Spacer()
            Text(monthTitle(vm.displayedMonth))
                .font(.headline)
            Spacer()
            Button {
                vm.moveMonth(1)
            } label: {
                Image(systemName: "chevron.right")
            }
        }
    }
    
    private var weekdayHeader: some View {
        let symbols = cal.shortStandaloneWeekdaySymbols
        return HStack {
            ForEach(symbols, id: \.self) { s in
                Text(s)
                    .font(.caption)
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var calendarGrid: some View {
        let dates = vm.monthDates()
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 12) {
            ForEach(Array(dates.enumerated()), id: \.offset) { _, date in
                dayCell(date)
            }
        }
    }
    
    @ViewBuilder
    private func dayCell(_ date: Date?) -> some View {
        if let day = date {
            let inPeriod = vm.isInPeriod(day)
            let status = ExhibitionScheduleUtils.openingStatus(on: day, exhibition: vm.exhibition)
            let isClosed = isClosedStatus(status)
            Button {
                vm.selectedDate = day
                vm.showDaySheet = true
            } label: {
                Text("\(cal.component(.day, from: day))")
                    .frame(maxWidth: .infinity, minHeight: 34)
                    .foregroundStyle(isClosed ? .secondary : .primary)
                    .opacity(inPeriod ? 1.0 : 0.2)
            }
            .disabled(!inPeriod)
        } else {
            Text(" ")
                .frame(maxWidth: .infinity, minHeight: 34)
                .hidden()
        }
    }
    
    private func monthTitle(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = cal
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy年M月"
        return formatter.string(from: date)
    }
    
    private func isClosedStatus(_ status: OpeningStatus) -> Bool {
        if case .closed = status { return true }
        return false
    }
}

struct ExhibitionDayStatusSheet: View {
    let date: Date
    let exhibition: Exhibition
    
    var body: some View {
        let status = ExhibitionScheduleUtils.openingStatus(on: date, exhibition: exhibition)
        VStack(spacing: 16) {
            Text(date.ymdString)
                .font(.headline)
            switch status {
            case .closed:
                Text("休館日")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 8))
            case let .open(openTime, closeTime, lastEntryTime):
                VStack(spacing: 6) {
                    Text("本日の開館時間")
                        .font(.subheadline)
                    Text("\(openTime)–\(closeTime)")
                        .font(.title3.bold())
                    if let last = lastEntryTime {
                        Text("最終入場 \(last)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
        }
        .padding()
    }
}
