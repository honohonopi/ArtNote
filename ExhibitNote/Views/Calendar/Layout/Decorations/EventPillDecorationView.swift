//
//  EventPillDecorationView.swift
//  ArtNote
//
//  Created by Honoka Nishiyama on 2025/10/18.
//

// 展覧会の帯を描画
import UIKit

final class EventPillLayoutAttributes: UICollectionViewLayoutAttributes {
    var title: String = ""
    var color: UIColor? = nil
    var isClosed: Bool = false
    override func copy(with zone: NSZone? = nil) -> Any {
        let c = super.copy(with: zone) as! EventPillLayoutAttributes
        c.title = title
        c.color = color
        c.isClosed = isClosed
        return c
    }
}

final class EventPillDecorationView: UICollectionReusableView {
    private let label = UILabel()
    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = UIColor(red: 0.86, green: 0.92, blue: 1.0, alpha: 1.0)
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
            if a.isClosed {
                backgroundColor = UIColor.systemGray5
                label.textColor = .secondaryLabel
            } else if let c = a.color {
                backgroundColor = c
                let isDark = (0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b) < 0.5
                label.textColor = isDark ? .white : .label
            }
        }
    }
}

private extension UIColor {
    var r: CGFloat { var v: CGFloat = 0; getRed(&v, green: nil, blue: nil, alpha: nil); return v }
    var g: CGFloat { var v: CGFloat = 0; getRed(nil, green: &v, blue: nil, alpha: nil); return v }
    var b: CGFloat { var v: CGFloat = 0; getRed(nil, green: nil, blue: &v, alpha: nil); return v }
}
