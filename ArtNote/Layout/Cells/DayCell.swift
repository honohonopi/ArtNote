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
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(text: String, dimmed: Bool, isToday: Bool) {
        label.text = text
        label.textColor = dimmed ? .tertiaryLabel : .label
        // 今日ハイライトをセル背景でやらない場合はここは .clear のまま
    }
}
