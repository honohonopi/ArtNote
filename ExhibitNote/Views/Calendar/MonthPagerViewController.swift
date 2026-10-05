//
//  MonthPagerViewController.swift
//  ArtNote
//
//  Created by Honoka Nishiyama on 2025/10/03.
//

import UIKit
import SwiftData

final class MonthPagerViewController: UIPageViewController, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
    
    private let cal = Calendar.japan
    private var exhibitions: [Exhibition] = []
    private var currentVC: MonthCalendarViewController!
    private var lastSignature: [String] = []
    var onMonthChanged: ((Date) -> Void)?
    var onDaySelected: ((Date) -> Void)?
    
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
        lastSignature = exhibitions.map {
            [
                String(describing: $0.persistentModelID),
                String($0.startDate.timeIntervalSince1970),
                String($0.endDate.timeIntervalSince1970),
                $0.title,
                $0.venue
            ].joined(separator: "|")
        }
        configureCallbacks(for: currentVC)
        setViewControllers([currentVC], direction: .forward, animated: false)
        onMonthChanged?(currentVC.currentMonthAnchor)
    }
    
    // MARK: - DataSource（前後の月）
    func pageViewController(_ pageViewController: UIPageViewController,
                            viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let vc = viewController as? MonthCalendarViewController else { return nil }
        guard let prev = cal.date(byAdding: .month, value: -1, to: vc.currentMonthAnchor) else { return nil }
        return makeMonthViewController(month: prev)
    }
    
    func pageViewController(_ pageViewController: UIPageViewController,
                            viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let vc = viewController as? MonthCalendarViewController else { return nil }
        guard let next = cal.date(byAdding: .month, value: 1, to: vc.currentMonthAnchor) else { return nil }
        return makeMonthViewController(month: next)
    }
    
    // MARK: - Delegate（ページ送り完了）
    func pageViewController(_ pageViewController: UIPageViewController,
                            didFinishAnimating finished: Bool,
                            previousViewControllers: [UIViewController],
                            transitionCompleted completed: Bool) {
        if completed, let vc = viewControllers?.first as? MonthCalendarViewController {
            currentVC = vc
            onMonthChanged?(vc.currentMonthAnchor)
        }
    }
    
    // MARK: - 外部からの更新
    func update(exhibitions: [Exhibition]) {
        let signature = exhibitions.map {
            [
                String(describing: $0.persistentModelID),
                String($0.startDate.timeIntervalSince1970),
                String($0.endDate.timeIntervalSince1970),
                $0.title,
                $0.venue
            ].joined(separator: "|")
        }
        if signature == lastSignature { return }
        lastSignature = signature
        self.exhibitions = exhibitions
        if let vc = viewControllers?.first as? MonthCalendarViewController {
            vc.configure(with: exhibitions)
        }
    }
    
    /// 指定日を含む「月」へページジャンプ
    func jumpToMonth(containing date: Date, animated: Bool = true) {
        // 現在の月とターゲットの月の差分（±何ヶ月）を求める
        let delta = monthsBetween(currentVC.currentMonthAnchor, date)
        guard delta != 0 else {
            onMonthChanged?(currentVC.currentMonthAnchor)
            return
        }
        guard let target = cal.date(byAdding: .month, value: delta, to: currentVC.currentMonthAnchor) else { return }
        let nextVC = makeMonthViewController(month: target)
        let dir: UIPageViewController.NavigationDirection = (delta >= 0) ? .forward : .reverse
        setViewControllers([nextVC], direction: dir, animated: animated) { [weak self] done in
            guard done else { return }
            self?.currentVC = nextVC
            self?.onMonthChanged?(nextVC.currentMonthAnchor)
        }
    }

    func showMonth(containing date: Date) {
        guard monthsBetween(currentVC.currentMonthAnchor, date) != 0 else { return }
        jumpToMonth(containing: date)
    }

    private func makeMonthViewController(month: Date) -> MonthCalendarViewController {
        let viewController = MonthCalendarViewController(
            month: month,
            exhibitions: exhibitions
        )
        configureCallbacks(for: viewController)
        return viewController
    }

    private func configureCallbacks(for viewController: MonthCalendarViewController) {
        viewController.onDaySelected = { [weak self] date in
            self?.onDaySelected?(date)
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
