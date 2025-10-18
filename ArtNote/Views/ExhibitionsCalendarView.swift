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
    
    var body: some View {
        NavigationStack {
            MonthPagerRepresentable()
                .navigationTitle(navTitle.isEmpty ? "会期カレンダー" : navTitle)
            // 月タイトル同期（既存）
                .onReceive(NotificationCenter.default.publisher(for: .calendarMonthTitleUpdated)) { output in
                    if let title = output.object as? String {
                        navTitle = title
                    }
                }
            // ★ 日付タップ受信 → シートを出す
                .onReceive(NotificationCenter.default.publisher(for: .calendarDayTapped)) { out in
                    guard let date = out.object as? Date else { return }
                    vm.selectedDate = date
                    vm.showDaySheet = true
                }
            // ★ その日の展示一覧（モーダル/Navigation付き）
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
            // ★（必要なら）フルスクリーン詳細もここで扱える
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
