//
//  PRPackageCell.swift
//  Pyra
//  Created by Fauxly on 06.07.2026.

import UIKit

final class PRPackageCell: UICollectionViewCell {

    static let reuseIdentifier = "PRPackageCell"

    private let iconView = UIImageView()
    private let nameLabel = UILabel()

    // Задача загрузки иконки для ТЕКУЩЕГО содержимого ячейки. Отменяется при переиспользовании,
    // чтобы результат старой загрузки не "выстрелил" в уже переиспользованную под другой пакет ячейку.
    private var iconLoadTask: Task<Void, Never>?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) не поддерживается")
    }

    private func setupViews() {
        contentView.backgroundColor = PRTheme.surface
        contentView.layer.cornerRadius = 16
        contentView.layer.borderWidth = 0
        contentView.layer.borderColor = PRTheme.brass.cgColor
        contentView.clipsToBounds = true

        // Тень — на слое самой ячейки, а не contentView: у contentView clipsToBounds = true
        // (нужен для скруглённых углов), и он обрезал бы свечение тени по краю.
        layer.shadowColor = PRTheme.brass.cgColor
        layer.shadowOpacity = 0
        layer.shadowRadius = 14
        layer.shadowOffset = .zero

        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = PRTheme.textSecondary
        iconView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(iconView)

        nameLabel.textColor = PRTheme.textPrimary
        nameLabel.font = UIFont.systemFont(ofSize: 22, weight: .semibold)
        nameLabel.textAlignment = .center
        nameLabel.numberOfLines = 3
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(nameLabel)

        NSLayoutConstraint.activate([
            iconView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 15),
            iconView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 90),
            iconView.heightAnchor.constraint(equalToConstant: 90),

            nameLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 12),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 15),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -15),
            nameLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -15)
        ])
    }

    func configure(with package: PRPackage) {
        nameLabel.text = package.name

        // Плейсхолдер сразу, чтобы не было пустого места, пока грузится (или если иконки нет вообще)
        iconView.image = UIImage(systemName: "shippingbox")

        iconLoadTask?.cancel()

        guard let iconURLString = package.iconURL, !iconURLString.isEmpty else { return }

        iconLoadTask = Task { [weak self] in
            let image = await PRImageCache.shared.image(for: iconURLString)

            // Проверяем отмену уже ПОСЛЕ await — если ячейку успели переиспользовать
            // под другой пакет, эта загрузка больше не актуальна
            guard !Task.isCancelled, let image else { return }

            await MainActor.run {
                self?.iconView.image = image
            }
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        iconLoadTask?.cancel()
        iconLoadTask = nil

        iconView.image = nil
        nameLabel.text = nil

        transform = .identity
        contentView.backgroundColor = PRTheme.surface
        contentView.layer.borderWidth = 0
        layer.shadowOpacity = 0
    }

    // MARK: - Focus Engine

    // Идиоматичный tvOS-паттерн: анимация фокуса живёт в самой ячейке, а не в делегате
    // коллекции с приведением типов — так контроллер не завязан на детали конкретной ячейки.
    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)

        if context.nextFocusedItem === self {
            coordinator.addCoordinatedAnimations({
                self.transform = CGAffineTransform(scaleX: 1.06, y: 1.06)
                self.contentView.backgroundColor = PRTheme.surfaceFocused
                self.contentView.layer.borderWidth = 2
                self.layer.shadowOpacity = 0.55
            }, completion: nil)
        } else if context.previouslyFocusedItem === self {
            coordinator.addCoordinatedAnimations({
                self.transform = .identity
                self.contentView.backgroundColor = PRTheme.surface
                self.contentView.layer.borderWidth = 0
                self.layer.shadowOpacity = 0
            }, completion: nil)
        }
    }
}
