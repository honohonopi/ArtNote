//
//  ExhibitionsCalendarView.swift
//  ArtNote
//
//  Created by Honoka Nishiyama on 2025/10/03.
//

// 会期カレンダー（UIKit を埋め込む）
import SwiftUI
import SwiftData

struct ExhibitionsCalendarView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: [SortDescriptor(\Exhibition.startDate, order: .forward)])
    private var exhibitions: [Exhibition]
    
    @StateObject private var vm = CalendarViewModel()
    @State private var navTitle: String = ""
    @State private var daySheetDetent: PresentationDetent = .medium
    
    private func formattedMonthTitle(from rawTitle: String) -> String {
        let formatter = DateFormatter.japanese()
        formatter.dateFormat = "MMMM yyyy"
        guard let date = formatter.date(from: rawTitle) else { return rawTitle }
        let jpFormatter = DateFormatter.japanese()
        jpFormatter.locale = Locale(identifier: "ja_JP")
        jpFormatter.dateFormat = "yyyy年M月"
        return jpFormatter.string(from: date)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 月タイトル（白）
                if !navTitle.isEmpty {
                    Text(formattedMonthTitle(from: navTitle))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.primary) // ← ダーク/ライトで自動
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .background(Color(uiColor: .systemBackground))
                }
                
                // カレンダー本体（白）
                ZStack {
                    Color(uiColor: .systemBackground)
                    MonthPagerRepresentable()
                        .onReceive(NotificationCenter.default.publisher(for: .calendarMonthTitleUpdated)) { output in
                            if let title = output.object as? String {
                                navTitle = title
                            }
                        }
                        .onReceive(NotificationCenter.default.publisher(for: .calendarDayTapped)) { out in
                            guard let date = out.object as? Date else { return }
                            vm.selectedDate = date
                            vm.showDaySheet = true
                        }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("今日") {
                        NotificationCenter.default.post(name: .calendarJumpToToday, object: nil)
                    }
                    .font(.body.weight(.semibold))
                    .accessibilityLabel("今日へ移動")
                }
            }
            .navigationTitle("会期カレンダー")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $vm.showDaySheet) {
                if let date = vm.selectedDate {
                    let content = DayExhibitionsListView(
                        date: date,
                        exhibitions: vm.exhibitions(on: date, from: exhibitions)
                    )
                    .presentationDetents([.medium, .large], selection: $daySheetDetent)
                    .presentationDragIndicator(.visible)
                    if #available(iOS 16.4, *) {
                        content.presentationBackground(Color(uiColor: .systemBackground))
                    } else {
                        content
                    }
                }
            }
        }
    }
    
}
