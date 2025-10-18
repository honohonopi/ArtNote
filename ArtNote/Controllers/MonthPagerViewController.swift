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

    private lazy var monthTitleFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "yyyy年M月"
        return f
    }()

    private func postMonthTitle(for month: Date) {
        let title = monthTitleFormatter.string(from: month)
        NotificationCenter.default.post(name: .calendarMonthTitleUpdated, object: title)
    }

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
        // 初期表示時にタイトル通知
        postMonthTitle(for: currentVC.currentMonthAnchor)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 画面復帰時にも再通知（タイトルが消えた時の保険）
        postMonthTitle(for: currentVC.currentMonthAnchor)
    }

    // MARK: - DataSource（前後の月）
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

    // MARK: - Delegate（ページ送り完了）
    func pageViewController(_ pageViewController: UIPageViewController,
                            didFinishAnimating finished: Bool,
                            previousViewControllers: [UIViewController],
                            transitionCompleted completed: Bool) {
        if completed, let vc = viewControllers?.first as? MonthCalendarViewController {
            currentVC = vc
            postMonthTitle(for: vc.currentMonthAnchor)
        }
    }

    // MARK: - 外部からの更新
    func update(exhibitions: [Exhibition]) {
        self.exhibitions = exhibitions
        // ページ再生成が必要ならここで対応
        postMonthTitle(for: currentVC.currentMonthAnchor) // 念のため再通知
    }

    // 任意：プログラムで月移動（前月:-1 / 次月:+1）
    func jump(byMonths delta: Int) {
        guard let target = cal.date(byAdding: .month, value: delta, to: currentVC.currentMonthAnchor) else { return }
        let vc = MonthCalendarViewController(month: target, exhibitions: exhibitions)
        let dir: UIPageViewController.NavigationDirection = (delta >= 0) ? .forward : .reverse
        setViewControllers([vc], direction: dir, animated: true) { [weak self] done in
            guard done else { return }
            self?.currentVC = vc
            self?.postMonthTitle(for: vc.currentMonthAnchor)
        }
    }
}
