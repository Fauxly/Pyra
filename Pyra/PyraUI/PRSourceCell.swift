//
//  PRSourceCell.swift
//  Pyra
//  Created by Fauxly on 27.09.2026.

import UIKit

/// Карточка источника: иконка репозитория (CydiaIcon.png), название, адрес, число пакетов
/// и значок статуса в углу — грузится / готово / пусто или недоступен.
final class PRSourceCell: PRCardCell {

    static let reuseIdentifier = "PRSourceCell"

    enum Status {
        case loading
        case ready(packageCount: Int)
        case empty
        case unknown // каталог ещё ни разу не загружался
    }

    private let iconView = PRCardCell.makeIconView(size: 96, cornerRadius: 24)
    private let nameLabel = PRCardCell.makeLabel(size: 30, weight: .bold, color: PRTheme.textPrimary)
    private let hostLabel = PRCardCell.makeLabel(size: 21, weight: .regular, color: PRTheme.textSecondary)
    private let countLabel = PRCardCell.makeLabel(size: 21, weight: .semibold, color: PRTheme.brass)
    private let statusView = UIImageView()
    private var iconTask: Task<Void, Never>?

    override init(frame: CGRect) {
        super.init(frame: frame)

        contentView.addSubview(iconView)

        nameLabel.adjustsFontSizeToFitWidth = true
        nameLabel.minimumScaleFactor = 0.6
        hostLabel.lineBreakMode = .byTruncatingMiddle

        let textStack = UIStackView(arrangedSubviews: [nameLabel, hostLabel, countLabel])
        textStack.axis = .vertical
        textStack.spacing = 4
        textStack.setCustomSpacing(10, after: hostLabel)
        textStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(textStack)

        statusView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 26, weight: .bold)
        statusView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(statusView)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 26),
            iconView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            textStack.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 24),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: statusView.leadingAnchor, constant: -12),
            textStack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            statusView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            statusView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) не поддерживается")
    }

    func configure(with repository: PRRepository, status: Status) {
        nameLabel.text = repository.name
        let isOfficial = repository.baseURL.host?.contains("procurs.us") == true
        hostLabel.text = isOfficial ? "SOURCES_OFFICIAL".localized : (repository.baseURL.host ?? repository.baseURL.absoluteString)

        PRCardCell.loadImage(repository.iconURL.absoluteString, into: iconView, placeholder: "shippingbox", task: &iconTask)
        apply(status)
    }

    private func apply(_ status: Status) {
        statusView.layer.removeAnimation(forKey: "spin")
        switch status {
        case .loading:
            countLabel.text = "SOURCES_STATUS_LOADING".localized
            countLabel.textColor = PRTheme.textSecondary
            statusView.image = UIImage(systemName: "arrow.triangle.2.circlepath")
            statusView.tintColor = PRTheme.brass
            let spin = CABasicAnimation(keyPath: "transform.rotation.z")
            spin.fromValue = 0
            spin.toValue = CGFloat.pi * 2
            spin.duration = 1.1
            spin.repeatCount = .infinity
            statusView.layer.add(spin, forKey: "spin")
        case .ready(let count):
            countLabel.text = String(format: "CATEGORIES_PACKAGE_COUNT".localized, count)
            countLabel.textColor = PRTheme.brass
            statusView.image = UIImage(systemName: "checkmark.circle.fill")
            statusView.tintColor = PRTheme.teal
        case .empty:
            countLabel.text = "SOURCES_STATUS_EMPTY".localized
            countLabel.textColor = PRTheme.textSecondary
            statusView.image = UIImage(systemName: "exclamationmark.triangle.fill")
            statusView.tintColor = UIColor(red: 0xE0 / 255, green: 0x8A / 255, blue: 0x7A / 255, alpha: 1)
        case .unknown:
            countLabel.text = " "
            statusView.image = nil
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        iconTask?.cancel()
        iconTask = nil
        statusView.layer.removeAnimation(forKey: "spin")
    }
}

/// Карточка "Добавить источник": пунктирная латунная рамка, плюс и подпись
final class PRAddSourceCell: PRCardCell {

    static let reuseIdentifier = "PRAddSourceCell"

    private let dashedBorder = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = .clear

        dashedBorder.strokeColor = PRTheme.brass.withAlphaComponent(0.7).cgColor
        dashedBorder.fillColor = UIColor.clear.cgColor
        dashedBorder.lineWidth = 3
        dashedBorder.lineDashPattern = [12, 10]
        contentView.layer.addSublayer(dashedBorder)

        let plus = UIImageView(image: UIImage(systemName: "plus.circle.fill"))
        plus.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 48, weight: .semibold)
        plus.tintColor = PRTheme.brass
        let label = PRCardCell.makeLabel(size: 28, weight: .bold, color: PRTheme.textPrimary)
        label.text = "SOURCES_ADD_CARD".localized

        let stack = UIStackView(arrangedSubviews: [plus, label])
        stack.axis = .horizontal
        stack.spacing = 18
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) не поддерживается")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        dashedBorder.frame = contentView.bounds
        dashedBorder.path = UIBezierPath(roundedRect: contentView.bounds.insetBy(dx: 1.5, dy: 1.5), cornerRadius: 24).cgPath
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        let focused = context.nextFocusedItem === self
        coordinator.addCoordinatedAnimations({
            self.contentView.backgroundColor = focused ? PRTheme.surface : .clear
        }, completion: nil)
    }
}
