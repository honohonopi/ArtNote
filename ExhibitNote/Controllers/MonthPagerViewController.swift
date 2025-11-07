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
        
        // 「今日へ」ジャンプ要求を購読
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleJumpToToday),
            name: .calendarJumpToToday,
            object: nil
        )
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 画面復帰時にも再通知（タイトルが消えた時の保険）
        postMonthTitle(for: currentVC.currentMonthAnchor)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: .calendarJumpToToday, object: nil)
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
        if let vc = viewControllers?.first as? MonthCalendarViewController {
            vc.configure(with: exhibitions)
        }
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
    
    
    // MARK: - 今日へジャンプ（通知ハンドラ）
    @objc private func handleJumpToToday() {
        jumpToMonth(containing: Date(), animated: true)
    }
    
    /// 指定日を含む「月」へページジャンプ
    func jumpToMonth(containing date: Date, animated: Bool = true) {
        // 現在の月とターゲットの月の差分（±何ヶ月）を求める
        let delta = monthsBetween(currentVC.currentMonthAnchor, date)
        guard delta != 0 else {
            // 同じ月ならタイトルだけ再通知
            postMonthTitle(for: currentVC.currentMonthAnchor)
            return
        }
        guard let target = cal.date(byAdding: .month, value: delta, to: currentVC.currentMonthAnchor) else { return }
        let nextVC = MonthCalendarViewController(month: target, exhibitions: exhibitions)
        let dir: UIPageViewController.NavigationDirection = (delta >= 0) ? .forward : .reverse
        setViewControllers([nextVC], direction: dir, animated: animated) { [weak self] done in
            guard done else { return }
            self?.currentVC = nextVC
            self?.postMonthTitle(for: nextVC.currentMonthAnchor)
        }
    }
    
    /// 2つの日付が属する「月」の月差（ターゲットが先なら正、過去なら負）
    private func monthsBetween(_ from: Date, _ to: Date) -> Int {
        let fromYM = cal.date(from: cal.dateComponents([.year, .month], from: from))!
        let toYM   = cal.date(from: cal.dateComponents([.year, .month], from: to))!
        let comps  = cal.dateComponents([.month], from: fromYM, to: toYM)
        return comps.month ?? 0
    }
}
