//
//  MonthCalendarViewController.swift
//  ArtNote
//
//  Created by Honoka Nishiyama on 2025/10/18.
//

import SwiftUI

final class MonthCalendarViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {
    
    private var cal: Calendar = {
        var c = Calendar.japan
        c.locale = Locale(identifier: "ja_JP")
        c.firstWeekday = 1  // ←月曜始まりにしたい場合は 2 に
        return c
    }()
    private var monthAnchor: Date = Calendar.japan.date(from: Calendar.japan.dateComponents([.year, .month], from: Date()))!
    
    private var daysMatrix: [[Date?]] = []
    private var collectionView: UICollectionView!
    private var currentExhibitions: [Exhibition] = [] // 直近のデータを保持
    var onDaySelected: ((Date) -> Void)?
    
    private let weekdayHeader = UIStackView()
    private var weekdayLabels: [UILabel] = []
    
    private var layout: MonthGridLayout!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        
        layout = MonthGridLayout()
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.allowsSelection = true
        collectionView.register(DayCell.self, forCellWithReuseIdentifier: DayCell.reuseID)
        
        // タップで indexPath を拾う（選択イベントが来なくても確実に拾う）
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleCollectionTap(_:)))
        tap.cancelsTouchesInView = false
        tap.delaysTouchesBegan = false
        collectionView.addGestureRecognizer(tap)
        
        // 追加：曜日ヘッダー（7列）
        weekdayHeader.axis = .horizontal
        weekdayHeader.alignment = .fill
        weekdayHeader.distribution = .fillEqually
        weekdayHeader.spacing = 0
        weekdayHeader.isLayoutMarginsRelativeArrangement = false
        
        // ラベル作成
        weekdayLabels = (0..<7).map { _ in
            let l = UILabel()
            l.font = .systemFont(ofSize: 12, weight: .semibold)
            l.textColor = .secondaryLabel
            l.textAlignment = .center
            return l
        }
        weekdayLabels.forEach { weekdayHeader.addArrangedSubview($0) }
        
        // 既存の追加順：タイトル → 曜日 → コレクション
        view.addSubview(weekdayHeader)
        view.addSubview(collectionView)
        
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        weekdayHeader.translatesAutoresizingMaskIntoConstraints = false
        weekdayHeader.leadingAnchor.constraint(equalTo: collectionView.leadingAnchor).isActive = true
        weekdayHeader.trailingAnchor.constraint(equalTo: collectionView.trailingAnchor).isActive = true
        
        NSLayoutConstraint.activate([
            
            // 曜日ヘッダー（タイトルの直下に固定）
            weekdayHeader.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 6),
            weekdayHeader.heightAnchor.constraint(equalToConstant: 20),
            
            // カレンダー本体（曜日ヘッダーの下から）
            collectionView.topAnchor.constraint(equalTo: weekdayHeader.bottomAnchor, constant: -8),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // 初期描画
        updateWeekdaySymbols()
        layout.setExhibitions(currentExhibitions)
        configure(with: currentExhibitions)
    }
    
    @objc private func handleCollectionTap(_ gr: UITapGestureRecognizer) {
        let point = gr.location(in: collectionView)
        guard let indexPath = collectionView.indexPathForItem(at: point) else { return }
        collectionView(collectionView, didSelectItemAt: indexPath)
    }
    
    func configure(with exhibitions: [Exhibition]) {
        self.currentExhibitions = exhibitions
        layout.setExhibitions(exhibitions)
        let data = MonthCalendarDataBuilder(calendar: cal).build(
            monthAnchor: monthAnchor,
            exhibitions: exhibitions
        )
        daysMatrix = data.daysMatrix
        layout.configure(
            weeks: daysMatrix.count,
            eventSpansBySection: data.eventSpansBySection
        )
        layout.invalidateLayout()
        
        collectionView?.reloadData()
        updateWeekdaySymbols()
    }
    
    
    // MARK: - DataSource
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return daysMatrix.count
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { 7 }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: DayCell.reuseID, for: indexPath) as! DayCell
        let date = daysMatrix[indexPath.section][indexPath.item]
        if let d = date {
            let day = cal.component(.day, from: d)
            let thisMonth = cal.component(.month, from: d) == cal.component(.month, from: monthAnchor)
            let weekday = cal.component(.weekday, from: d)
            let isHoliday = JapaneseHolidayService.isHoliday(d)
            let textColor = dayTextColor(weekday: weekday, isHoliday: isHoliday)
            cell.configure(text: "\(day)", dimmed: !thisMonth, isToday: cal.isDateInToday(d), textColor: textColor)
        } else {
            cell.configure(text: "", dimmed: true, isToday: false, textColor: .label)
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard indexPath.section < daysMatrix.count,
              indexPath.item < 7,
              let date = daysMatrix[indexPath.section][indexPath.item] else { return }
        
        let dayStart = cal.startOfDay(for: date)
        onDaySelected?(dayStart)
    }
    
    private func updateWeekdaySymbols() {
        // 「日/月/…」をロケール ja_JP で取得（端末言語に依存しない）
        let df = DateFormatter.japanese()
        df.calendar = cal
        df.locale   = cal.locale

        var syms = df.shortStandaloneWeekdaySymbols ?? ["日","月","火","水","木","金","土"]

        let rotate = max(0, cal.firstWeekday - 1)
        if rotate > 0 {
            syms = Array(syms.dropFirst(rotate)) + Array(syms.prefix(rotate))
        }

        for i in 0..<weekdayLabels.count {
            weekdayLabels[i].text = syms[i]

            let weekdayNumber = ((cal.firstWeekday + i - 1) % 7) + 1
            if weekdayNumber == 1 {
                weekdayLabels[i].textColor = .systemRed
            } else if weekdayNumber == 7 {
                weekdayLabels[i].textColor = .systemBlue
            } else {
                weekdayLabels[i].textColor = .secondaryLabel
            }
        }
    }

    private func dayTextColor(weekday: Int, isHoliday: Bool) -> UIColor {
        if isHoliday || weekday == 1 {
            return .systemRed
        }
        if weekday == 7 {
            return .systemBlue
        }
        return .label
    }

}

extension MonthCalendarViewController {
    // 月初に正規化
    fileprivate func startOfMonth(_ d: Date) -> Date {
        let c = Calendar.japan
        return c.date(from: c.dateComponents([.year, .month], from: d))!
    }
    
    // exhibitions を受けて表示する月を指定できる init
    convenience init(month: Date, exhibitions: [Exhibition]) {
        self.init()
        self.monthAnchor = startOfMonth(month)
        self.currentExhibitions = exhibitions
    }
    
    // 現在の月を取得（ページャが参照）
    var currentMonthAnchor: Date { monthAnchor }
}
