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

    func makeUIViewController(context: Context) -> MonthPagerViewController {
        MonthPagerViewController(exhibitions: exhibitions, initialMonth: Date())
    }

    func updateUIViewController(_ uiViewController: MonthPagerViewController, context: Context) {
        uiViewController.update(exhibitions: exhibitions) 
    }
}
