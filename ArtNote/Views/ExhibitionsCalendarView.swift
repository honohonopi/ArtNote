//
//  ExhibitionsCalendarView.swift
//  ArtNote
//
//  Created by Honoka Nishiyama on 2025/10/03.
//

import SwiftUI
import SwiftData
import UIKit

// 週内に横断して表示する帯の区間
struct EventSpan {
    let startColumn: Int  // 0...6
    let endColumn: Int    // 0...6
    let row: Int          // 段階1では常に 0（今後重なり解消で増える）
    let title: String
}

// 会期を週ごとに分割したサブ区間
struct WeekSpan {
    let weekStart: Date
    let start: Date
    let end: Date
}

// ============================================================
// SwiftUI ラッパ（このビューを .sheet などで開く）
// ============================================================
struct ExhibitionsCalendarView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            MonthPagerRepresentable()
                .navigationTitle("会期カレンダー")
        }
    }
}

// ============================================================
// UIViewControllerRepresentable → UIKit カレンダーVC
// ============================================================
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

// ============================================================
// 1ヶ月グリッド + 横断ピル表示（重なりは未対応）
// ============================================================
final class MonthCalendarViewController: UIViewController, UICollectionViewDataSource {
    
    private let cal = Calendar.current
    private var monthAnchor: Date = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date()))!
    
    private var daysMatrix: [[Date?]] = []     // 6週×7列（nil は前後月の空き）
    private var eventSpansBySection: [[EventSpan]] = [] // 週ごとの横断ピル（段階1は row=0 固定）
    private var collectionView: UICollectionView!
    private var currentExhibitions: [Exhibition] = [] // 直近のデータを保持
    private let monthTitleLabel = UILabel()
    private lazy var monthTitleFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "yyyy年M月"
        return f
    }()
    private let weekdayHeader = UIStackView()
    private var weekdayLabels: [UILabel] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let layout = MonthGridLayout()
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.dataSource = self
        collectionView.register(DayCell.self, forCellWithReuseIdentifier: DayCell.reuseID)

        // 追加：曜日ヘッダー（7列）
        weekdayHeader.axis = .horizontal
        weekdayHeader.alignment = .fill
        weekdayHeader.distribution = .fillEqually
        weekdayHeader.spacing = 0

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
        view.addSubview(monthTitleLabel)
        view.addSubview(weekdayHeader)
        view.addSubview(collectionView)

        collectionView.translatesAutoresizingMaskIntoConstraints = false
        monthTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        weekdayHeader.translatesAutoresizingMaskIntoConstraints = false

        // タイトル見た目
        monthTitleLabel.font = .boldSystemFont(ofSize: 20)
        monthTitleLabel.textAlignment = .center
        monthTitleLabel.textColor = .label

        NSLayoutConstraint.activate([
            // タイトル
            monthTitleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            monthTitleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            // 曜日ヘッダー（タイトルの直下に固定）
            weekdayHeader.topAnchor.constraint(equalTo: monthTitleLabel.bottomAnchor, constant: 6),
            weekdayHeader.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            weekdayHeader.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
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
        let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        swipeRight.direction = .right
        view.addGestureRecognizer(swipeLeft)
        view.addGestureRecognizer(swipeRight)

        // 初期描画
        updateWeekdaySymbols()   // ★ 追加
        if !currentExhibitions.isEmpty {
            configure(with: currentExhibitions)
        }
    }

    
    func configure(with exhibitions: [Exhibition]) {
        self.currentExhibitions = exhibitions
        
        // 1) 月のマトリクス
        daysMatrix = MonthCalendarViewController.buildDaysMatrix(for: monthAnchor, cal: cal)
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
            let spans = splitByWeek(start: s, end: e, cal: cal)
            for w in spans {
                guard let section = firstWeekStarts.firstIndex(of: w.weekStart) else { continue }
                let startCol = weekdayColumn(for: w.start, cal: cal)
                let endCol   = weekdayColumn(for: w.end,   cal: cal)
                eventSpansBySection[section].append(EventSpan(startColumn: startCol, endColumn: endCol, row: 0, title: ex.title))
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
        if let layout = collectionView?.collectionViewLayout as? MonthGridLayout {
            layout.configure(
                weeks: daysMatrix.count,
                eventSpansBySection: eventSpansBySection, // [[EventSpan]]（トップレベル型）
                maxRowsBySection: maxRowsBySection
            )
            layout.invalidateLayout()
        }
        collectionView?.reloadData()
        updateWeekdaySymbols()
        updateMonthTitle(exhibitions: exhibitions)
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
    
    // MARK: - Helpers
    
    private static func buildDaysMatrix(for monthAnchor: Date, cal: Calendar) -> [[Date?]] {
        let startOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: monthAnchor))!
        let daysInMonth = cal.range(of: .day, in: .month, for: startOfMonth)!.count
        let firstWeekdayIndex = (cal.component(.weekday, from: startOfMonth) - cal.firstWeekday + 7) % 7
        
        var matrix: [[Date?]] = []
        var row: [Date?] = Array(repeating: nil, count: 7)
        var day = 1
        // 1行目：前月の空白 + 当月
        for col in 0..<7 {
            if col >= firstWeekdayIndex {
                row[col] = cal.date(byAdding: .day, value: day - 1, to: startOfMonth)
                day += 1
            }
        }
        matrix.append(row)
        
        // 残り
        while day <= daysInMonth {
            var r: [Date?] = Array(repeating: nil, count: 7)
            for col in 0..<7 where day <= daysInMonth {
                r[col] = cal.date(byAdding: .day, value: day - 1, to: startOfMonth)
                day += 1
            }
            matrix.append(r)
        }
        // 6週に満たなければ空行で埋める
        while matrix.count < 6 { matrix.append(Array(repeating: nil, count: 7)) }
        return matrix
    }
    
    private func weekdayColumn(for date: Date, cal: Calendar) -> Int {
        (cal.component(.weekday, from: date) - cal.firstWeekday + 7) % 7
    }
    
    private func splitByWeek(start: Date, end: Date, cal: Calendar) -> [WeekSpan] {
        var out: [WeekSpan] = []
        var s = cal.startOfDay(for: start)
        let e = cal.startOfDay(for: end)
        while s <= e {
            let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: s))!
            let weekEnd = cal.date(byAdding: .day, value: 6, to: weekStart)!
            let subEnd = min(weekEnd, e)
            out.append(.init(weekStart: weekStart, start: s, end: subEnd))
            guard let next = cal.date(byAdding: .day, value: 1, to: subEnd) else { break }
            s = next
        }
        return out
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
                    result.append(EventSpan(startColumn: s.startColumn, endColumn: s.endColumn, row: r, title: s.title))
                    placed = true
                    break
                }
            }
            // 既存行すべて衝突 ⇒ 新規行を追加
            if !placed {
                rows.append([range])
                let r = rows.count - 1
                result.append(EventSpan(startColumn: s.startColumn, endColumn: s.endColumn, row: r, title: s.title))
            }
        }
        return (result, max(1, rows.count))
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
        var title = monthTitleFormatter.string(from: monthAnchor)
        monthTitleLabel.text = title
    }

    private func updateWeekdaySymbols() {
        // 例: ["日","月","火","水","木","金","土"] を firstWeekday に合わせて回転
        var syms = cal.shortStandaloneWeekdaySymbols  // 日曜始まりが前提の配列
        let rotate = max(0, cal.firstWeekday - 1)
        if rotate > 0 {
            syms = Array(syms.dropFirst(rotate)) + Array(syms.prefix(rotate))
        }

        for i in 0..<weekdayLabels.count {
            weekdayLabels[i].text = syms[i]

            // weekend の色（firstWeekday に依存させて計算）
            // 列 i の実際の曜日番号（1=Sun ... 7=Sat）
            let weekdayNumber = ((cal.firstWeekday + i - 1) % 7) + 1
            if weekdayNumber == 1 { // Sunday
                weekdayLabels[i].textColor = .systemRed
            } else if weekdayNumber == 7 { // Saturday
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

// ============================================================
// カスタムレイアウト：7列×(5〜6)週 ＋ 週内の横断ピル
// ============================================================
final class MonthGridLayout: UICollectionViewLayout {
    
    // 表示寸法（固定）
    private let dayHeight: CGFloat = 84          // ★ 固定セル高さ
    private let sectionSpacing: CGFloat = 12
    private let sectionTopInset: CGFloat = 8
    private let pillHeight: CGFloat = 18
    private let pillVerticalOffset: CGFloat = 28
    private let pillRowSpacing: CGFloat = 2
    private let maxVisibleRows: Int = 3          // ★ 1週あたり最大3行まで表示
    
    // 計算キャッシュ
    private var contentSize: CGSize = .zero
    private var itemAttributes: [IndexPath: UICollectionViewLayoutAttributes] = [:]
    private var pillAttributes: [UICollectionViewLayoutAttributes] = []
    
    private var weeks: Int = 6
    private var eventSpansBySection: [[EventSpan]] = []
    private var maxRowsBySection: [Int] = []      // （高さ固定のため実質参照しませんが、受け取りは維持）
    
    static let pillKind = "EventPillDecoration"
    static let dayOverflowKind = "DayOverflowDecoration"
    private var dayOverflowAttributes: [UICollectionViewLayoutAttributes] = []
    
    override init() {
        super.init()
        self.register(EventPillDecorationView.self, forDecorationViewOfKind: Self.pillKind)
        self.register(DayOverflowDecorationView.self, forDecorationViewOfKind: Self.dayOverflowKind)
    }
    required init?(coder: NSCoder) { fatalError() }
    
    // 週ごとの行数情報は受け取るが、高さは固定のまま
    func configure(weeks: Int, eventSpansBySection: [[EventSpan]], maxRowsBySection: [Int]) {
        self.weeks = weeks
        self.eventSpansBySection = eventSpansBySection
        self.maxRowsBySection = maxRowsBySection
    }
    
    override func prepare() {
        super.prepare()
        guard let cv = collectionView else { return }
        
        itemAttributes.removeAll()
        pillAttributes.removeAll()
        dayOverflowAttributes.removeAll() // ★ 追加
        
        let width = CGFloat(cv.bounds.width)
        let dayWidth = floor(width / 7.0)
        
        var y: CGFloat = sectionTopInset
        for section in 0..<weeks {
            
            // --- 日セル（固定高さ） ---
            for col in 0..<7 {
                let indexPath = IndexPath(item: col, section: section)
                let attr = UICollectionViewLayoutAttributes(forCellWith: indexPath)
                let x = CGFloat(col) * dayWidth
                attr.frame = CGRect(x: x, y: y, width: dayWidth, height: dayHeight)
                itemAttributes[indexPath] = attr
            }
            
            // --- ピル（最大3行まで） ---
            if section < eventSpansBySection.count {
                let spans = eventSpansBySection[section]
                for (i, span) in spans.enumerated() {
                    guard span.row < maxVisibleRows else { continue } // 4行目以降は描かない
                    let startX = CGFloat(span.startColumn) * dayWidth + 2
                    let endX = CGFloat(span.endColumn + 1) * dayWidth - 2
                    let frame = CGRect(
                        x: startX,
                        y: y + pillVerticalOffset + CGFloat(span.row) * (pillHeight + pillRowSpacing),
                        width: max(8, endX - startX),
                        height: pillHeight
                    )
                    let attr = EventPillLayoutAttributes(
                        forDecorationViewOfKind: Self.pillKind,
                        with: IndexPath(item: i, section: section)
                    )
                    attr.frame = frame
                    attr.zIndex = 1024
                    attr.title = span.title
                    pillAttributes.append(attr)
                }
                
                // --- 日別オーバーフロー（4行目以降が存在する列に "…" を置く） ---
                // 対象：この週の各列 0...6
                for col in 0..<7 {
                    // この列に「row >= 3」の帯が一つでも跨っていれば true
                    let hasOverflowHere = spans.contains { span in
                        guard span.row >= maxVisibleRows else { return false }
                        return span.startColumn <= col && col <= span.endColumn
                    }
                    guard hasOverflowHere else { continue }
                    
                    // 対象セルの左下に小さく配置
                    let cellIndexPath = IndexPath(item: col, section: section)
                    guard let cellFrame = itemAttributes[cellIndexPath]?.frame else { continue }
                    
                    let size = CGSize(width: 10, height: 12) // ラベル "…" の小さな領域
                    let frame = CGRect(
                        x: cellFrame.minX + 4,
                        y: cellFrame.maxY,
                        width: size.width,
                        height: size.height
                    )
                    
                    let attr = DayOverflowLayoutAttributes(
                        forDecorationViewOfKind: Self.dayOverflowKind,
                        with: IndexPath(item: col, section: section) // 列ごとにユニーク
                    )
                    attr.frame = frame
                    attr.zIndex = 2001
                    attr.show = true
                    dayOverflowAttributes.append(attr)
                }
            }
            
            y += dayHeight + sectionSpacing
        }
        
        contentSize = CGSize(width: width, height: y)
    }
    
    override var collectionViewContentSize: CGSize { contentSize }
    
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        var attrs: [UICollectionViewLayoutAttributes] = []
        for a in itemAttributes.values where a.frame.intersects(rect) { attrs.append(a) }
        for a in pillAttributes where a.frame.intersects(rect) { attrs.append(a) }
        for a in dayOverflowAttributes where a.frame.intersects(rect) { attrs.append(a) } // ★ 追加
        return attrs
    }
    
    override func layoutAttributesForDecorationView(ofKind elementKind: String, at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        if elementKind == Self.pillKind {
            return pillAttributes.first { $0.indexPath == indexPath && $0.representedElementKind == elementKind }
        } else if elementKind == Self.dayOverflowKind {
            return dayOverflowAttributes.first { $0.indexPath == indexPath && $0.representedElementKind == elementKind }
        }
        return nil
    }
    
    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        itemAttributes[indexPath]
    }
    
    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        guard let oldSize = collectionView?.bounds.size else { return true }
        return oldSize != newBounds.size
    }
}


// ============================================================
// Day セル（数字だけ）
// ============================================================
final class DayCell: UICollectionViewCell {
    static let reuseID = "DayCell"
    private let label = UILabel()
    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = .clear
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        contentView.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 6)
        ])
    }
    required init?(coder: NSCoder) { fatalError() }
    func configure(text: String, dimmed: Bool, isToday: Bool) {
        label.text = text
        label.textColor = dimmed ? .tertiaryLabel : .label
        //        contentView.layer.cornerRadius = 10
        //        contentView.backgroundColor = isToday ? UIColor.secondarySystemFill : .clear
    }
}

// ============================================================
// 横断ピル（DecorationView）
// ============================================================
final class EventPillLayoutAttributes: UICollectionViewLayoutAttributes {
    var title: String = ""
    override func copy(with zone: NSZone? = nil) -> Any {
        let c = super.copy(with: zone) as! EventPillLayoutAttributes
        c.title = title
        return c
    }
}

final class EventPillDecorationView: UICollectionReusableView {
    private let label = UILabel()
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.systemBlue.withAlphaComponent(0.18)
        layer.cornerRadius = 8
        layer.masksToBounds = true
        
        label.font = .systemFont(ofSize: 11, weight: .semibold)
        label.textColor = .label
        addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            label.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -6),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
    required init?(coder: NSCoder) { fatalError() }
    
    override func apply(_ layoutAttributes: UICollectionViewLayoutAttributes) {
        super.apply(layoutAttributes)
        if let a = layoutAttributes as? EventPillLayoutAttributes {
            label.text = a.title
        }
    }
}

final class DayOverflowLayoutAttributes: UICollectionViewLayoutAttributes {
    var show: Bool = false
    override func copy(with zone: NSZone? = nil) -> Any {
        let c = super.copy(with: zone) as! DayOverflowLayoutAttributes
        c.show = show
        return c
    }
    override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? DayOverflowLayoutAttributes else { return false }
        return super.isEqual(object) && other.show == show
    }
}

final class DayOverflowDecorationView: UICollectionReusableView {
    private let label = UILabel()
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        label.text = "…"
        label.font = .systemFont(ofSize: 12, weight: .bold)
        label.textColor = .secondaryLabel
        addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor),
            label.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    required init?(coder: NSCoder) { fatalError() }
    
    override func apply(_ layoutAttributes: UICollectionViewLayoutAttributes) {
        super.apply(layoutAttributes)
        // 今回は常に "…" 固定表示（count表示にしたくなったらここで分岐）
    }
}
