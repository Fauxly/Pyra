//
//  PRShelfCells.swift
//  Pyra
//  Created by Fauxly on 27.09.2026.

import UIKit

/// Широкая карточка полки "Новое и обновлённое": иконка слева, название, версия латунью
/// и первая строка описания — видно, что именно вышло, не заходя в пакет.
final class PRWideCardCell: PRCardCell {

    static let reuseIdentifier = "PRWideCardCell"

    private let iconView = PRCardCell.makeIconView(size: 110, cornerRadius: 26)
    private let nameLabel = PRCardCell.makeLabel(size: 28, weight: .bold, color: PRTheme.textPrimary)
    private let versionLabel = PRCardCell.makeLabel(size: 22, weight: .semibold, color: PRTheme.brass)
    private let descriptionLabel = PRCardCell.makeLabel(size: 21, weight: .regular, color: PRTheme.textSecondary)
    private let statusBadge = UIImageView()
    private var package: PRPackage?
    private var iconTask: Task<Void, Never>?

    override init(frame: CGRect) {
        super.init(frame: frame)
        focusScale = 1.05

        contentView.addSubview(iconView)
        nameLabel.adjustsFontSizeToFitWidth = true
        nameLabel.minimumScaleFactor = 0.7
        descriptionLabel.numberOfLines = 2

        let textStack = UIStackView(arrangedSubviews: [nameLabel, versionLabel, descriptionLabel])
        textStack.axis = .vertical
        textStack.spacing = 4
        textStack.setCustomSpacing(8, after: versionLabel)
        textStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(textStack)

        statusBadge.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 24, weight: .bold)
        statusBadge.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(statusBadge)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            iconView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            textStack.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 24),
            textStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -48),
            textStack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            statusBadge.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            statusBadge.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        ])

        NotificationCenter.default.addObserver(self, selector: #selector(installedStateDidChange),
                                               name: PRInstalledState.didChangeNotification, object: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) не поддерживается")
    }

    func configure(with package: PRPackage) {
        self.package = package
        nameLabel.text = package.name
        versionLabel.text = "v\(package.version)"
        // Первая строка описания — это краткое описание (synopsis) из control-файла
        let synopsis = package.description.components(separatedBy: "\n").first ?? ""
        descriptionLabel.text = synopsis
        descriptionLabel.isHidden = synopsis.isEmpty
        PRCardCell.loadImage(package.iconURL, into: iconView, placeholder: "shippingbox", task: &iconTask)
        updateStatusBadge()
    }

    private func updateStatusBadge() {
        guard let package else { statusBadge.isHidden = true; return }
        switch PRInstalledState.shared.status(for: package) {
        case .notInstalled:
            statusBadge.isHidden = true
        case .installed:
            statusBadge.image = UIImage(systemName: "checkmark.circle.fill")
            statusBadge.tintColor = PRTheme.teal
            statusBadge.isHidden = false
        case .updateAvailable:
            statusBadge.image = UIImage(systemName: "arrow.down.circle.fill")
            statusBadge.tintColor = PRTheme.brass
            statusBadge.isHidden = false
        }
    }

    @objc private func installedStateDidChange() {
        updateStatusBadge()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        iconTask?.cancel()
        iconTask = nil
        package = nil
    }
}

/// Таблетка полки "Категории": цвет и иконка категории, название и число пакетов.
/// Ширина — по содержимому (self-sizing).
final class PRCategoryChipCell: PRCardCell {

    static let reuseIdentifier = "PRCategoryChipCell"

    private let iconView = UIImageView()
    private let titleLabel = PRCardCell.makeLabel(size: 26, weight: .bold, color: PRTheme.textPrimary)
    private let countLabel = PRCardCell.makeLabel(size: 22, weight: .semibold, color: PRTheme.textSecondary)

    override init(frame: CGRect) {
        super.init(frame: frame)
        focusScale = 1.08
        contentView.layer.cornerRadius = 40

        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 26, weight: .semibold)
        iconView.setContentHuggingPriority(.required, for: .horizontal)

        let stack = UIStackView(arrangedSubviews: [iconView, titleLabel, countLabel])
        stack.axis = .horizontal
        stack.spacing = 12
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 30),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -30),
            stack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) не поддерживается")
    }

    func configure(name: String, count: Int) {
        let style = PRCategoryStyle.style(for: name)
        contentView.backgroundColor = style.color.withAlphaComponent(0.2)
        iconView.image = UIImage(systemName: style.symbol)
        iconView.tintColor = style.color
        titleLabel.text = name
        countLabel.text = "\(count)"
        countLabel.textColor = style.color
    }
}

/// Последняя плитка ряда репозитория: "Все N →" — открывает весь репозиторий
final class PRSeeAllCell: PRCardCell {

    static let reuseIdentifier = "PRSeeAllCell"

    private let dashedBorder = CAShapeLayer()
    private let titleLabel = PRCardCell.makeLabel(size: 28, weight: .bold, color: PRTheme.brass)

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = .clear
        contentView.layer.cornerRadius = 16

        dashedBorder.strokeColor = PRTheme.brass.withAlphaComponent(0.7).cgColor
        dashedBorder.fillColor = UIColor.clear.cgColor
        dashedBorder.lineWidth = 3
        dashedBorder.lineDashPattern = [12, 10]
        contentView.layer.addSublayer(dashedBorder)

        let arrow = UIImageView(image: UIImage(systemName: "arrow.right.circle.fill"))
        arrow.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 44, weight: .semibold)
        arrow.tintColor = PRTheme.brass
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 2

        let stack = UIStackView(arrangedSubviews: [arrow, titleLabel])
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 12)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) не поддерживается")
    }

    func configure(total: Int) {
        titleLabel.text = String(format: "DASHBOARD_SEE_ALL".localized, total)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        dashedBorder.frame = contentView.bounds
        dashedBorder.path = UIBezierPath(roundedRect: contentView.bounds.insetBy(dx: 1.5, dy: 1.5), cornerRadius: 16).cgPath
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        let focused = context.nextFocusedItem === self
        coordinator.addCoordinatedAnimations({
            self.contentView.backgroundColor = focused ? PRTheme.surface : .clear
        }, completion: nil)
    }
}
