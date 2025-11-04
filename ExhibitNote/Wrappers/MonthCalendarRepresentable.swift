//
//  Untitled.swift
//  ArtNote
//
//  Created by Honoka Nishiyama on 2025/10/18.
//

import SwiftUI

struct MonthCalendarRepresentable: UIViewControllerRepresentable {
    let exhibitions: [Exhibition]
    func makeUIViewController(context: Context) -> MonthCalendarViewController {
        let vc = MonthCalendarViewController()
        vc.configure(with: exhibitions)
        return vc
    }
    func updateUIViewController(_ uiViewController: MonthCalendarViewController, context: Context) {
        uiViewController.configure(with: exhibitions)
    }
}
