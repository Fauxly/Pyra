//
//  PRPackageCell.swift
//  Pyra
//  Created by Fauxly on 06.07.2026.

import UIKit

final class PRPackageCell: UICollectionViewCell {

    static let reuseIdentifier = "PRPackageCell"

    private let iconView = UIImageView()
    private let nameLabel = UILabel()
    /// Автор под названием (без почты из поля Author)
    private let authorLabel = UILabel()

    /// Значок в углу плитки: галочка — установлен, стрелка — есть обновление
    private let statusBadge = UIImageView()

    private var package: PRPackage?

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
        nameLabel.numberOfLines = 2
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(nameLabel)

        authorLabel.textColor = PRTheme.textSecondary
        authorLabel.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        authorLabel.textAlignment = .center
        authorLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(authorLabel)

        statusBadge.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 30, weight: .bold)
        statusBadge.backgroundColor = PRTheme.ink
        statusBadge.layer.cornerRadius = 20
        statusBadge.contentMode = .center
        statusBadge.isHidden = true
        statusBadge.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(statusBadge)

        // Установка/удаление где угодно в приложении → значки на всех видимых плитках
        // обновляются сами, без перезагрузки коллекций
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(installedStateDidChange),
            name: PRInstalledState.didChangeNotification,
            object: nil
        )

        NSLayoutConstraint.activate([
            iconView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 15),
            iconView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 90),
            iconView.heightAnchor.constraint(equalToConstant: 90),

            nameLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 12),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 15),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -15),

            authorLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            authorLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 15),
            authorLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -15),
            authorLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -12),

            statusBadge.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            statusBadge.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            statusBadge.widthAnchor.constraint(equalToConstant: 40),
            statusBadge.heightAnchor.constraint(equalToConstant: 40)
        ])
    }

    func configure(with package: PRPackage) {
        self.package = package
        nameLabel.text = package.name
        var author = package.author?.trimmingCharacters(in: .whitespaces) ?? ""
        if let bracket = author.firstIndex(of: "<") {
            author = String(author[..<bracket]).trimmingCharacters(in: .whitespaces)
        }
        authorLabel.text = author
        updateStatusBadge()

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

    private func updateStatusBadge() {
        guard let package else {
            statusBadge.isHidden = true
            return
        }
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

        iconLoadTask?.cancel()
        iconLoadTask = nil

        iconView.image = nil
        nameLabel.text = nil
        authorLabel.text = nil
        package = nil
        statusBadge.isHidden = true

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
