//
//  MonthGridLayout.swift
//  ArtNote
//
//  Created by Honoka Nishiyama on 2025/10/18.
//

import UIKit
import SwiftData

final class MonthGridLayout: UICollectionViewLayout {
    
    // 表示寸法（固定）
    private let dayHeight: CGFloat = 100          // ★ 固定セル高さ
    private let sectionSpacing: CGFloat = 0
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
    
    static let gridKind = "GridDecoration"
    private var gridAttributes: [UICollectionViewLayoutAttributes] = []
    
    private var exhibitionLookup: [PersistentIdentifier: Exhibition] = [:]
    
    override init() {
        super.init()
        self.register(EventPillDecorationView.self, forDecorationViewOfKind: Self.pillKind)
        self.register(DayOverflowDecorationView.self, forDecorationViewOfKind: Self.dayOverflowKind)
        self.register(GridDecorationView.self, forDecorationViewOfKind: Self.gridKind)
    }
    required init?(coder: NSCoder) { fatalError() }
    
    // 週ごとの行数情報は受け取るが、高さは固定のまま
    func configure(weeks: Int, eventSpansBySection: [[EventSpan]], maxRowsBySection: [Int]) {
        self.weeks = weeks
        self.eventSpansBySection = eventSpansBySection
        self.maxRowsBySection = maxRowsBySection
    }
    
    func setExhibitions(_ exhibitions: [Exhibition]) {
            exhibitionLookup = Dictionary(uniqueKeysWithValues:
                exhibitions.map { ($0.persistentModelID, $0) }
            )
        }
    
    override func prepare() {
        super.prepare()
        guard let cv = collectionView else { return }
        
        itemAttributes.removeAll()
        pillAttributes.removeAll()
        dayOverflowAttributes.removeAll()
        gridAttributes.removeAll()
        
        let width = CGFloat(cv.bounds.width)
        let dayWidth = floor(width / 7.0)
        
        var y: CGFloat = sectionTopInset
        for section in 0..<weeks {
            
            let gridIndexPath = IndexPath(item: 0, section: section)
            let gridAttr = GridLayoutAttributes(
                forDecorationViewOfKind: Self.gridKind,
                with: gridIndexPath
            )
            gridAttr.frame = CGRect(x: 0, y: y, width: width, height: dayHeight)
            gridAttr.zIndex = 10 // セル(0)の背面 or 同等。ピル(1024)より十分下
            gridAttr.columns = 7
            gridAttr.lineWidth = 0.5
            gridAttr.insets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
            gridAttributes.append(gridAttr)
            
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
                    if let ex = exhibitionLookup[span.exhibitionID],
                       let c = ex.uiColor {
                        attr.color = c
                    } else {
                        attr.color = UIColor(red: 0.86, green: 0.92, blue: 1.0, alpha: 1.0)
                    }
                    attr.isClosed = span.isClosed
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
                        y: cellFrame.maxY - size.height - 2,
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
        for a in gridAttributes where a.frame.intersects(rect) { attrs.append(a) }   // ★ 追加
        for a in itemAttributes.values where a.frame.intersects(rect) { attrs.append(a) }
        for a in pillAttributes where a.frame.intersects(rect) { attrs.append(a) }
        for a in dayOverflowAttributes where a.frame.intersects(rect) { attrs.append(a) }
        return attrs
    }

    override func layoutAttributesForDecorationView(ofKind elementKind: String, at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        if elementKind == Self.gridKind {
            return gridAttributes.first { $0.indexPath == indexPath && $0.representedElementKind == elementKind }
        }
        if elementKind == Self.pillKind {
            return pillAttributes.first { $0.indexPath == indexPath && $0.representedElementKind == elementKind }
        }
        if elementKind == Self.dayOverflowKind {
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
