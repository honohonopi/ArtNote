//
//  MonthPagerViewController.swift
//  ArtNote
//
//  Created by Honoka Nishiyama on 2025/10/03.
//

import UIKit
import SwiftData

final class MonthPagerViewController: UIPageViewController, UIPageViewControllerDataSource, UIPageViewControllerDelegate {

    private let cal = Calendar.current
    private var exhibitions: [Exhibition] = []
    private var currentVC: MonthCalendarViewController!

    init(exhibitions: [Exhibition], initialMonth: Date = Date()) {
        super.init(transitionStyle: .scroll, navigationOrientation: .horizontal)
        self.exhibitions = exhibitions
        self.currentVC = MonthCalendarViewController(month: initialMonth, exhibitions: exhibitions)
        self.dataSource = self
        self.delegate = self
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        setViewControllers([currentVC], direction: .forward, animated: false)
    }

    // MARK: - DataSource (前後の月を生成)
    func pageViewController(_ pageViewController: UIPageViewController,
                            viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let vc = viewController as? MonthCalendarViewController else { return nil }
        guard let prev = cal.date(byAdding: .month, value: -1, to: vc.currentMonthAnchor) else { return nil }
        return MonthCalendarViewController(month: prev, exhibitions: exhibitions)
    }

    func pageViewController(_ pageViewController: UIPageViewController,
                            viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let vc = viewController as? MonthCalendarViewController else { return nil }
        guard let next = cal.date(byAdding: .month, value: 1, to: vc.currentMonthAnchor) else { return nil }
        return MonthCalendarViewController(month: next, exhibitions: exhibitions)
    }

    // MARK: - Delegate（ページ送り完了時に currentVC を更新）
    func pageViewController(_ pageViewController: UIPageViewController,
                            didFinishAnimating finished: Bool,
                            previousViewControllers: [UIViewController],
                            transitionCompleted completed: Bool) {
        if completed, let vc = viewControllers?.first as? MonthCalendarViewController {
            currentVC = vc
        }
    }
}
