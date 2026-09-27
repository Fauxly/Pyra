//
//  PRCategoryCell.swift
//  Pyra
//  Created by Fauxly on 27.09.2026.

import UIKit

/// Плитка категории: цветной отлив из угла, иконка категории, название, число пакетов
/// и превью иконок нескольких пакетов из неё в правом нижнем углу.
final class PRCategoryCell: PRCardCell {

    static let reuseIdentifier = "PRCategoryCell"

    private let glowView = PRGradientView()
    private let iconBadge = UIView()
    private let iconView = UIImageView()
    private let nameLabel = PRCardCell.makeLabel(size: 32, weight: .bold, color: PRTheme.textPrimary)
    private let countLabel = PRCardCell.makeLabel(size: 22, weight: .medium, color: PRTheme.textSecondary)
    private let previewStack = UIStackView()
    private var previewTasks: [Task<Void, Never>?] = []

    override init(frame: CGRect) {
        super.init(frame: frame)

        glowView.gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        glowView.gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        glowView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(glowView)

        iconBadge.layer.cornerRadius = 20
        iconBadge.layer.cornerCurve = .continuous
        iconBadge.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(iconBadge)

        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 34, weight: .semibold)
        iconView.contentMode = .center
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconBadge.addSubview(iconView)

        nameLabel.adjustsFontSizeToFitWidth = true
        nameLabel.minimumScaleFactor = 0.6
        contentView.addSubview(nameLabel)
        contentView.addSubview(countLabel)

        previewStack.axis = .horizontal
        previewStack.spacing = -12 // иконки чуть наезжают друг на друга, как стопка
        previewStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(previewStack)

        NSLayoutConstraint.activate([
            glowView.topAnchor.constraint(equalTo: contentView.topAnchor),
            glowView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            glowView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            glowView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

            iconBadge.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 26),
            iconBadge.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 26),
            iconBadge.widthAnchor.constraint(equalToConstant: 76),
            iconBadge.heightAnchor.constraint(equalToConstant: 76),
            iconView.centerXAnchor.constraint(equalTo: iconBadge.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconBadge.centerYAnchor),

            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 26),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -26),
            nameLabel.bottomAnchor.constraint(equalTo: countLabel.topAnchor, constant: -4),

            countLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 26),
            countLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24),

            previewStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -22),
            previewStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 30)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) не поддерживается")
    }

    func configure(name: String, count: Int, previewIconURLs: [String]) {
        let style = PRCategoryStyle.style(for: name)

        nameLabel.text = name
        countLabel.text = String(format: "CATEGORIES_PACKAGE_COUNT".localized, count)

        glowView.gradientLayer.colors = [
            style.color.withAlphaComponent(0.32).cgColor,
            style.color.withAlphaComponent(0.0).cgColor
        ]
        iconBadge.backgroundColor = style.color.withAlphaComponent(0.22)
        iconView.image = UIImage(systemName: style.symbol) ?? UIImage(systemName: "square.grid.2x2")
        iconView.tintColor = style.color

        previewTasks.forEach { $0?.cancel() }
        previewTasks = []
        previewStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for url in previewIconURLs.prefix(3) {
            let preview = PRCardCell.makeIconView(size: 52, cornerRadius: 14)
            preview.layer.borderWidth = 2
            preview.layer.borderColor = PRTheme.surface.cgColor
            previewStack.addArrangedSubview(preview)
            var task: Task<Void, Never>?
            PRCardCell.loadImage(url, into: preview, placeholder: "shippingbox", task: &task)
            previewTasks.append(task)
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        previewTasks.forEach { $0?.cancel() }
        previewTasks = []
        previewStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
    }
}
