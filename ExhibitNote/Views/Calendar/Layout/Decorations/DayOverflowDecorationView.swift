//
//  DayOverflowDecorationView.swift
//  ArtNote
//
//  Created by Honoka Nishiyama on 2025/10/18.
//

// “…” 表示を描画
import UIKit

final class DayOverflowLayoutAttributes: UICollectionViewLayoutAttributes {
    var show: Bool = false
    override func copy(with zone: NSZone? = nil) -> Any {
        let c = super.copy(with: zone) as! DayOverflowLayoutAttributes
        c.show = show
        return c
    }
}

final class DayOverflowDecorationView: UICollectionReusableView {
    private let label = UILabel()
    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
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
}
