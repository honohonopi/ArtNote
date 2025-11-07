//
//  DayCell.swift
//  ArtNote
//
//  Created by Honoka Nishiyama on 2025/10/18.
//

import UIKit

final class DayCell: UICollectionViewCell {
    static let reuseID = "DayCell"
    private let label = UILabel()
    private let todayBackground = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(label)
        contentView.insertSubview(todayBackground, belowSubview: label) // 丸はラベルの下
        
        label.translatesAutoresizingMaskIntoConstraints = false
        todayBackground.translatesAutoresizingMaskIntoConstraints = false
        
        todayBackground.isHidden = true
        todayBackground.backgroundColor = UIColor.systemBlue
        todayBackground.layer.cornerRadius = 10
        todayBackground.layer.masksToBounds = true
        
        NSLayoutConstraint.activate([
            // ラベル：上部中央
            label.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            label.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            
            // 丸背景：ラベル中心に合わせる（20x20の円）
            todayBackground.widthAnchor.constraint(equalToConstant: 20),
            todayBackground.heightAnchor.constraint(equalToConstant: 20),
            todayBackground.centerXAnchor.constraint(equalTo: label.centerXAnchor),
            todayBackground.centerYAnchor.constraint(equalTo: label.centerYAnchor)
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(text: String, dimmed: Bool, isToday: Bool) {
        label.text = text
        label.textColor = dimmed ? .tertiaryLabel : .label
        todayBackground.isHidden = !isToday
        if isToday { label.textColor = .white }
    }
    
    override func layoutSubviews() { super.layoutSubviews() }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        todayBackground.isHidden = true
        todayBackground.layer.borderWidth = 0
    }
}
