//
//  PRUpdateCell.swift
//  Pyra
//  Created by Fauxly on 27.09.2026.

import UIKit

/// Широкая карточка обновления: иконка, название, версии плашками "было → станет"
/// и размер загрузки.
final class PRUpdateCell: PRCardCell {

    static let reuseIdentifier = "PRUpdateCell"

    private let iconView = PRCardCell.makeIconView(size: 104, cornerRadius: 26)
    private let nameLabel = PRCardCell.makeLabel(size: 30, weight: .bold, color: PRTheme.textPrimary)
    private let oldVersionLabel = PRPillLabel()
    private let arrowView = UIImageView(image: UIImage(systemName: "arrow.right"))
    private let newVersionLabel = PRPillLabel()
    private let sizeLabel = PRCardCell.makeLabel(size: 20, weight: .medium, color: PRTheme.textSecondary)
    private var iconTask: Task<Void, Never>?

    override init(frame: CGRect) {
        super.init(frame: frame)
        focusScale = 1.04

        contentView.addSubview(iconView)

        nameLabel.adjustsFontSizeToFitWidth = true
        nameLabel.minimumScaleFactor = 0.6

        for (label, background, text) in [
            (oldVersionLabel, PRTheme.surfaceFocused, PRTheme.textSecondary),
            (newVersionLabel, PRTheme.brass.withAlphaComponent(0.2), PRTheme.brass)
        ] {
            label.font = UIFont.monospacedDigitSystemFont(ofSize: 22, weight: .semibold)
            label.backgroundColor = background
            label.textColor = text
            label.layer.cornerRadius = 12
            label.clipsToBounds = true
            label.lineBreakMode = .byTruncatingMiddle
        }
        arrowView.tintColor = PRTheme.textSecondary
        arrowView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 18, weight: .bold)
        arrowView.setContentHuggingPriority(.required, for: .horizontal)

        let versionsRow = UIStackView(arrangedSubviews: [oldVersionLabel, arrowView, newVersionLabel])
        versionsRow.axis = .horizontal
        versionsRow.spacing = 10
        versionsRow.alignment = .center

        let textStack = UIStackView(arrangedSubviews: [nameLabel, versionsRow, sizeLabel])
        textStack.axis = .vertical
        textStack.alignment = .leading
        textStack.spacing = 10
        textStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(textStack)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 26),
            iconView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            textStack.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 28),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -26),
            textStack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) не поддерживается")
    }

    func configure(name: String, installedVersion: String, available: PRPackage) {
        nameLabel.text = name
        oldVersionLabel.text = installedVersion
        newVersionLabel.text = available.version

        if let size = available.size, size > 0 {
            let formatter = ByteCountFormatter()
            formatter.countStyle = .file
            sizeLabel.text = String(format: "UPDATES_DOWNLOAD_SIZE".localized, formatter.string(fromByteCount: size))
            sizeLabel.isHidden = false
        } else {
            sizeLabel.isHidden = true
        }

        PRCardCell.loadImage(available.iconURL, into: iconView, placeholder: "shippingbox", task: &iconTask)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        iconTask?.cancel()
        iconTask = nil
    }
}
