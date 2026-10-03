//
//  GridDecorationView.swift.swift
//  ArtNote
//
//  Created by Honoka Nishiyama on 2025/10/18.
//

// 格子線を描画
import UIKit

final class GridLayoutAttributes: UICollectionViewLayoutAttributes {
    var columns: Int = 7
    var lineWidth: CGFloat = 0.5
    var insets: UIEdgeInsets = .zero
    override func copy(with zone: NSZone? = nil) -> Any {
        let c = super.copy(with: zone) as! GridLayoutAttributes
        c.columns = columns
        c.lineWidth = lineWidth
        c.insets = insets
        return c
    }
}

final class GridDecorationView: UICollectionReusableView {
    override class var layerClass: AnyClass { CAShapeLayer.self }
    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
    }
    required init?(coder: NSCoder) { fatalError() }

    override func apply(_ layoutAttributes: UICollectionViewLayoutAttributes) {
        super.apply(layoutAttributes)
        guard let a = layoutAttributes as? GridLayoutAttributes,
              let layer = self.layer as? CAShapeLayer else { return }

        let rect = bounds.inset(by: a.insets)
        let path = UIBezierPath()
        let colW = rect.width / CGFloat(max(1, a.columns))

        // 外枠
        path.move(to: .init(x: rect.minX, y: rect.minY))
        path.addLine(to: .init(x: rect.maxX, y: rect.minY))
        path.addLine(to: .init(x: rect.maxX, y: rect.maxY))
        path.addLine(to: .init(x: rect.minX, y: rect.maxY))
        path.close()

        // 縦線
        for i in 1..<a.columns {
            let x = rect.minX + CGFloat(i) * colW
            path.move(to: .init(x: x, y: rect.minY))
            path.addLine(to: .init(x: x, y: rect.maxY))
        }

        layer.path = path.cgPath
        layer.strokeColor = UIColor.systemGray4.cgColor
        layer.lineWidth = a.lineWidth
        layer.fillColor = UIColor.clear.cgColor
    }
}
