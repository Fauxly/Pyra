//
//  PRStatTileView.swift
//  Pyra
//  Created by Fauxly on 27.09.2026.

import UIKit

/// Плашка статистики (не фокусируется): мелкая подпись сверху, крупное число снизу
final class PRStatTileView: UIView {

    private let captionLabel = UILabel()
    private let valueLabel = UILabel()

    init(caption: String, valueColor: UIColor = PRTheme.textPrimary) {
        super.init(frame: .zero)
        backgroundColor = PRTheme.surface
        layer.cornerRadius = 22
        layer.cornerCurve = .continuous

        captionLabel.text = caption.uppercased()
        captionLabel.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        captionLabel.textColor = PRTheme.textSecondary

        valueLabel.font = UIFont.systemFont(ofSize: 44, weight: .heavy)
        valueLabel.textColor = valueColor
        valueLabel.adjustsFontSizeToFitWidth = true
        valueLabel.minimumScaleFactor = 0.6

        let stack = UIStackView(arrangedSubviews: [captionLabel, valueLabel])
        stack.axis = .vertical
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -28),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) не поддерживается")
    }

    var value: String? {
        get { valueLabel.text }
        set { valueLabel.text = newValue }
    }
}
