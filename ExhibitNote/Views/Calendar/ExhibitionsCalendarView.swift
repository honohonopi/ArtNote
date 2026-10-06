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
    
    @State private var vm = CalendarViewModel()
    @State private var currentMonth = Date()
    @State private var daySheetDetent: PresentationDetent = .medium
    
    private var monthTitle: String {
        let formatter = DateFormatter.japanese()
        formatter.dateFormat = "yyyy年M月"
        return formatter.string(from: currentMonth)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 月タイトル（白）
                Text(monthTitle)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .background(Color(uiColor: .systemBackground))
                
                // カレンダー本体（白）
                ZStack {
                    Color(uiColor: .systemBackground)
                    MonthPagerRepresentable(currentMonth: $currentMonth) { date in
                        vm.selectedDate = date
                        vm.showDaySheet = true
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("今日") {
                        currentMonth = Date()
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
