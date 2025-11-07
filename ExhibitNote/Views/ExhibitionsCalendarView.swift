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
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        guard let date = formatter.date(from: rawTitle) else { return rawTitle }
        let jpFormatter = DateFormatter()
        jpFormatter.locale = Locale(identifier: "ja_JP")
        jpFormatter.dateFormat = "yyyy年M月"
        return jpFormatter.string(from: date)
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                // 背景（全体を灰色にする）
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // 月タイトル（白）
                    if !navTitle.isEmpty {
                        Text(formattedMonthTitle(from: navTitle))
                            .font(.system(size: 28, weight: .bold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                            .padding(.top, 8)
                            .background(Color.white)
                    }

                    // カレンダー本体（白）
                    ZStack {
                        Color.white
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
            }
            .navigationTitle("カレンダー")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(uiColor: .systemGroupedBackground), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .sheet(isPresented: $vm.showDaySheet) {
                if let date = vm.selectedDate {
                    DayExhibitionsListView(
                        date: date,
                        exhibitions: vm.exhibitions(on: date, from: exhibitions),
                        onSelect: { ex in
                            vm.selectedExhibitionForFullScreen = ex
                        }
                    )
                    .presentationDetents([.medium, .large], selection: $daySheetDetent)
                    .presentationDragIndicator(.visible)
                }
            }
            .fullScreenCover(item: $vm.selectedExhibitionForFullScreen) { ex in
                NavigationStack {
                    ExhibitionDetailView(exhibition: ex)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button("閉じる") { vm.selectedExhibitionForFullScreen = nil }
                            }
                        }
                }
            }
        }
    }

}
