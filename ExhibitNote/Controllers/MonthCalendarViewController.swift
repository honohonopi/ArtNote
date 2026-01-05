//
//  MonthCalendarViewController.swift
//  ArtNote
//
//  Created by Honoka Nishiyama on 2025/10/18.
//

import SwiftUI

final class MonthCalendarViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {
    
    private var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.locale = Locale(identifier: "ja_JP")
        c.firstWeekday = 1  // ←月曜始まりにしたい場合は 2 に
        return c
    }()
    private var monthAnchor: Date = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date()))!
    
    private var daysMatrix: [[Date?]] = []     // 6週×7列（nil は前後月の空き）
    private var eventSpansBySection: [[EventSpan]] = [] // 週ごとの横断ピル（段階1は row=0 固定）
    private var collectionView: UICollectionView!
    private var currentExhibitions: [Exhibition] = [] // 直近のデータを保持
    
    private let weekdayHeader = UIStackView()
    private var weekdayLabels: [UILabel] = []
    
    private var layout: MonthGridLayout!
    
    private lazy var monthTitleFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "yyyy年M月"
        return f
    }()
    
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
        
        // 左右スワイプ（既存）
        let swipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        swipeLeft.direction = .left
        swipeLeft.cancelsTouchesInView = false
        let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        swipeRight.direction = .right
        swipeRight.cancelsTouchesInView = false
        view.addGestureRecognizer(swipeLeft)
        view.addGestureRecognizer(swipeRight)
        
        // 初期描画
        updateWeekdaySymbols()
        if !currentExhibitions.isEmpty {
            layout.setExhibitions(currentExhibitions)
            configure(with: currentExhibitions)
        }
    }
    
    @objc private func handleCollectionTap(_ gr: UITapGestureRecognizer) {
        let point = gr.location(in: collectionView)
        guard let indexPath = collectionView.indexPathForItem(at: point) else { return }
        collectionView(collectionView, didSelectItemAt: indexPath)
    }
    
    func configure(with exhibitions: [Exhibition]) {
        self.currentExhibitions = exhibitions
        layout.setExhibitions(exhibitions)
        // 1) 月のマトリクス
        daysMatrix = CalendarEventSpanBuilder.buildDaysMatrix(for: monthAnchor, cal: cal)
        let weeks = daysMatrix.count
        
        // 各週の開始日の Date（週スタート＝ISO週の月曜など）
        let firstWeekStarts: [Date] = (0..<weeks).map { i in
            let row = daysMatrix[i]
            let first = row.compactMap { $0 }.first ?? monthAnchor
            return Calendar.current.date(from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: first))!
        }
        
        // 2) 週ごとの横断スパン（まず row=0 で作る）
        eventSpansBySection = Array(repeating: [], count: weeks)
        
        // 当月にクロップして週分割
        let monthStart = monthAnchor
        let monthEnd = cal.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart) ?? monthStart
        
        for ex in exhibitions {
            let s = max(cal.startOfDay(for: ex.startDate), monthStart)
            let e = min(cal.startOfDay(for: ex.endDate), monthEnd)
            guard s <= e else { continue }
            
            // 週に分割
            let spans = CalendarEventSpanBuilder.splitByWeek(start: s, end: e, cal: cal)
            for w in spans {
                guard let section = firstWeekStarts.firstIndex(of: w.weekStart) else { continue }
                let spansForWeek = buildEventSpansForWeek(exhibition: ex, weekSpan: w)
                eventSpansBySection[section].append(contentsOf: spansForWeek)
            }
        }
        
        // 3) 行割当て（重なり解消）＆各週の最大行数を把握
        var maxRowsBySection: [Int] = Array(repeating: 1, count: weeks)
        for sec in 0..<eventSpansBySection.count {
            let (withRows, rowsCount) = assignRows(spans: eventSpansBySection[sec])
            eventSpansBySection[sec] = withRows
            maxRowsBySection[sec] = rowsCount
        }
        
        // 4) レイアウトへ供給（あなたのレイアウトは固定高さ＋最大3行表示）
        layout.configure(
            weeks: daysMatrix.count,
            eventSpansBySection: eventSpansBySection, // [[EventSpan]]（トップレベル型）
            maxRowsBySection: maxRowsBySection
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
            cell.configure(text: "\(day)", dimmed: !thisMonth, isToday: cal.isDateInToday(d))
        } else {
            cell.configure(text: "", dimmed: true, isToday: false)
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard indexPath.section < daysMatrix.count,
              indexPath.item < 7,
              let date = daysMatrix[indexPath.section][indexPath.item] else { return }
        
        let dayStart = cal.startOfDay(for: date)
        // 当日を含む展示を抽出
        let shows = currentExhibitions.filter { ex in
            let s = cal.startOfDay(for: ex.startDate)
            let e = cal.startOfDay(for: ex.endDate)
            return s <= dayStart && dayStart <= e
        }
        
        NotificationCenter.default.post(name: .calendarDayTapped, object: dayStart)
    }
    
    // 帯の列レンジが重なるか
    private func overlaps(_ a: ClosedRange<Int>, _ b: ClosedRange<Int>) -> Bool {
        a.overlaps(b)
    }
    
    // 同一週の EventSpan に行番号（row）を割り当て、必要行数を返す
    private func assignRows(spans: [EventSpan]) -> ([EventSpan], Int) {
        // 左から右へ。長いものを先に置くと見栄えが安定
        let ordered = spans.sorted {
            if $0.startColumn != $1.startColumn { return $0.startColumn < $1.startColumn }
            return ($0.endColumn - $0.startColumn) > ($1.endColumn - $1.startColumn)
        }
        
        var rows: [[ClosedRange<Int>]] = [] // 各行に既に置いたレンジ集合
        var result: [EventSpan] = []
        
        for s in ordered {
            let range = s.startColumn...s.endColumn
            var placed = false
            // 空いている最小行に置く
            for r in 0..<rows.count {
                let conflict = rows[r].contains { overlaps($0, range) }
                if !conflict {
                    rows[r].append(range)
                    result.append(EventSpan(startColumn: s.startColumn,
                                            endColumn: s.endColumn,
                                            row: r,
                                            title: s.title,
                                            exhibitionID: s.exhibitionID,
                                            isClosed: s.isClosed))
                    placed = true
                    break
                }
            }
            // 既存行すべて衝突 ⇒ 新規行を追加
            if !placed {
                rows.append([range])
                let r = rows.count - 1
                result.append(EventSpan(startColumn: s.startColumn,
                                        endColumn: s.endColumn,
                                        row: r,
                                        title: s.title,
                                        exhibitionID: s.exhibitionID,
                                        isClosed: s.isClosed))
            }
        }
        return (result, max(1, rows.count))
    }

    private func buildEventSpansForWeek(exhibition: Exhibition, weekSpan: WeekSpan) -> [EventSpan] {
        var spans: [EventSpan] = []
        var cursor = cal.startOfDay(for: weekSpan.start)
        let end = cal.startOfDay(for: weekSpan.end)
        
        var currentStart: Date? = nil
        var currentClosed: Bool? = nil
        
        while cursor <= end {
            let status = ExhibitionScheduleUtils.openingStatus(on: cursor, exhibition: exhibition)
            let isClosed: Bool
            if case .closed = status {
                isClosed = true
            } else {
                isClosed = false
            }
            
            if currentClosed == nil {
                currentClosed = isClosed
                currentStart = cursor
            } else if currentClosed != isClosed {
                if let start = currentStart {
                    spans.append(makeSpan(exhibition: exhibition,
                                          start: start,
                                          end: cal.date(byAdding: .day, value: -1, to: cursor) ?? start,
                                          isClosed: currentClosed ?? false))
                }
                currentClosed = isClosed
                currentStart = cursor
            }
            guard let next = cal.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        if let start = currentStart, let closed = currentClosed {
            spans.append(makeSpan(exhibition: exhibition, start: start, end: end, isClosed: closed))
        }
        return spans
    }
    
    private func makeSpan(exhibition: Exhibition, start: Date, end: Date, isClosed: Bool) -> EventSpan {
        let startCol = CalendarEventSpanBuilder.weekdayColumn(for: start, cal: cal)
        let endCol = CalendarEventSpanBuilder.weekdayColumn(for: end, cal: cal)
        return EventSpan(startColumn: startCol,
                         endColumn: endCol,
                         row: 0,
                         title: exhibition.title,
                         exhibitionID: exhibition.persistentModelID,
                         isClosed: isClosed)
    }
    
    @objc private func handleSwipe(_ gr: UISwipeGestureRecognizer) {
        switch gr.direction {
        case .left:  shiftMonth(+1) // 次の月へ
        case .right: shiftMonth(-1) // 前の月へ
        default: break
        }
    }
    
    private func shiftMonth(_ delta: Int) {
        if let newAnchor = cal.date(byAdding: .month, value: delta, to: monthAnchor) {
            monthAnchor = cal.date(from: cal.dateComponents([.year, .month], from: newAnchor))!
            configure(with: currentExhibitions)
        }
    }
    
    private func updateMonthTitle(exhibitions: [Exhibition]) {
    }
    
    private func updateWeekdaySymbols() {
        // 「日/月/…」をロケール ja_JP で取得（端末言語に依存しない）
        let df = DateFormatter()
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

}

extension MonthCalendarViewController {
    // 月初に正規化
    fileprivate func startOfMonth(_ d: Date) -> Date {
        let c = Calendar.current
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
