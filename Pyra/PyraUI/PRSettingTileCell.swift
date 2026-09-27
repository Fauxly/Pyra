//
//  PRSettingTileCell.swift
//  Pyra
//  Created by Fauxly on 27.09.2026.

import UIKit

/// Плитка настройки: цветная иконка, название, текущее значение и — для переключателей —
/// "таблетка" вкл/выкл справа.
final class PRSettingTileCell: PRCardCell {

    static let reuseIdentifier = "PRSettingTileCell"

    private let iconBadge = UIView()
    private let iconView = UIImageView()
    private let titleLabel = PRCardCell.makeLabel(size: 28, weight: .bold, color: PRTheme.textPrimary)
    private let valueLabel = PRCardCell.makeLabel(size: 22, weight: .medium, color: PRTheme.textSecondary)
    private let toggleTrack = UIView()
    private let toggleKnob = UIView()
    private var knobLeading: NSLayoutConstraint!
    private var knobTrailing: NSLayoutConstraint!

    override init(frame: CGRect) {
        super.init(frame: frame)
        focusScale = 1.04

        iconBadge.layer.cornerRadius = 22
        iconBadge.layer.cornerCurve = .continuous
        iconBadge.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(iconBadge)

        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 34, weight: .semibold)
        iconView.contentMode = .center
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconBadge.addSubview(iconView)

        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.7
        let textStack = UIStackView(arrangedSubviews: [titleLabel, valueLabel])
        textStack.axis = .vertical
        textStack.spacing = 4
        textStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(textStack)

        toggleTrack.layer.cornerRadius = 22
        toggleTrack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(toggleTrack)
        toggleKnob.backgroundColor = PRTheme.textPrimary
        toggleKnob.layer.cornerRadius = 17
        toggleKnob.translatesAutoresizingMaskIntoConstraints = false
        toggleTrack.addSubview(toggleKnob)

        knobLeading = toggleKnob.leadingAnchor.constraint(equalTo: toggleTrack.leadingAnchor, constant: 5)
        knobTrailing = toggleKnob.trailingAnchor.constraint(equalTo: toggleTrack.trailingAnchor, constant: -5)

        NSLayoutConstraint.activate([
            iconBadge.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 26),
            iconBadge.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconBadge.widthAnchor.constraint(equalToConstant: 80),
            iconBadge.heightAnchor.constraint(equalToConstant: 80),
            iconView.centerXAnchor.constraint(equalTo: iconBadge.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconBadge.centerYAnchor),

            textStack.leadingAnchor.constraint(equalTo: iconBadge.trailingAnchor, constant: 26),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: toggleTrack.leadingAnchor, constant: -20),
            textStack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            toggleTrack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -30),
            toggleTrack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            toggleTrack.widthAnchor.constraint(equalToConstant: 84),
            toggleTrack.heightAnchor.constraint(equalToConstant: 44),
            toggleKnob.centerYAnchor.constraint(equalTo: toggleTrack.centerYAnchor),
            toggleKnob.widthAnchor.constraint(equalToConstant: 34),
            toggleKnob.heightAnchor.constraint(equalToConstant: 34)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) не поддерживается")
    }

    /// toggle == nil — обычная плитка-действие, без переключателя
    func configure(symbol: String, color: UIColor, title: String, value: String?, highlightValue: Bool, toggle: Bool?) {
        iconBadge.backgroundColor = color.withAlphaComponent(0.2)
        iconView.image = UIImage(systemName: symbol)
        iconView.tintColor = color
        titleLabel.text = title
        valueLabel.text = value
        valueLabel.isHidden = (value ?? "").isEmpty
        valueLabel.textColor = highlightValue ? PRTheme.brass : PRTheme.textSecondary

        toggleTrack.isHidden = toggle == nil
        let isOn = toggle ?? false
        toggleTrack.backgroundColor = isOn ? PRTheme.brass : PRTheme.surfaceFocused
        toggleKnob.backgroundColor = isOn ? PRTheme.ink : PRTheme.textSecondary
        // Сначала выключаем, потом включаем — иначе на миг активны оба и Auto Layout ругается
        if isOn {
            knobLeading.isActive = false
            knobTrailing.isActive = true
        } else {
            knobTrailing.isActive = false
            knobLeading.isActive = true
        }
    }
}
