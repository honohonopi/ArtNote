//
//  MonthPagerRepresentable.swift
//  ArtNote
//
//  Created by Honoka Nishiyama on 2025/10/03.
//

import SwiftUI
import SwiftData

struct MonthPagerRepresentable: UIViewControllerRepresentable {
    @Query(sort: [SortDescriptor(\Exhibition.startDate, order: .forward)]) private var exhibitions: [Exhibition]
    @Binding var currentMonth: Date
    let onDaySelected: (Date) -> Void

    func makeUIViewController(context: Context) -> MonthPagerViewController {
        let viewController = MonthPagerViewController(
            exhibitions: exhibitions,
            initialMonth: currentMonth
        )
        configureCallbacks(for: viewController)
        return viewController
    }

    func updateUIViewController(_ uiViewController: MonthPagerViewController, context: Context) {
        configureCallbacks(for: uiViewController)
        uiViewController.update(exhibitions: exhibitions)
        uiViewController.showMonth(containing: currentMonth)
    }

    private func configureCallbacks(for viewController: MonthPagerViewController) {
        viewController.onMonthChanged = { month in
            currentMonth = month
        }
        viewController.onDaySelected = onDaySelected
    }
}
