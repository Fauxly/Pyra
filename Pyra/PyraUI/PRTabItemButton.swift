//
//  PRTabItemButton.swift
//  Pyra
//  Created by Fauxly on 26.09.2026.

import UIKit

/// Вкладка верхнего бара: иконка НАД подписью + опциональный бейдж-счётчик в углу иконки.
/// Сделана на UIControl, а не UIButton: у UIButton на tvOS картинка и заголовок жёстко
/// стоят в строку, а системная конфигурация кнопки добавляет свой фокус-эффект, который
/// спорит с нашей латунной подсветкой.
final class PRTabItemButton: UIControl {

    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let badgeLabel = PRBadgeLabel()
    private let highlightView = UIView()

    /// Активная вкладка — латунная иконка/подпись на чуть более светлой подложке
    var isSelectedTab: Bool = false {
        didSet { applyAppearance(animated: true) }
    }

    /// Число на бейдже; 0 или меньше — бейдж скрыт
    var badgeCount: Int = 0 {
        didSet {
            badgeLabel.text = badgeCount > 99 ? "99+" : "\(badgeCount)"
            badgeLabel.isHidden = badgeCount <= 0
        }
    }

    init(title: String, systemImage: String) {
        super.init(frame: .zero)
        setup(title: title, systemImage: systemImage)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) не поддерживается")
    }

    override var canBecomeFocused: Bool { true }

    // MARK: - Вёрстка

    private func setup(title: String, systemImage: String) {
        // Подложка — отдельной view, а не backgroundColor самого контрола: так её можно
        // скруглить/подсветить независимо от тени и масштаба всего контрола в фокусе
        highlightView.isUserInteractionEnabled = false
        highlightView.layer.cornerRadius = 22
        highlightView.layer.cornerCurve = .continuous
        highlightView.layer.borderColor = PRTheme.brass.cgColor
        highlightView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(highlightView)

        iconView.image = UIImage(systemName: systemImage)
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 34, weight: .semibold)
        iconView.contentMode = .center
        iconView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconView)

        titleLabel.text = title
        titleLabel.font = UIFont.systemFont(ofSize: 22, weight: .semibold)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        badgeLabel.font = UIFont.systemFont(ofSize: 17, weight: .bold)
        badgeLabel.textColor = PRTheme.ink
        badgeLabel.backgroundColor = PRTheme.brass
        badgeLabel.textAlignment = .center
        badgeLabel.layer.cornerRadius = 14
        badgeLabel.clipsToBounds = true
        badgeLabel.isHidden = true
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(badgeLabel)

        layer.shadowColor = PRTheme.brass.cgColor
        layer.shadowOpacity = 0
        layer.shadowRadius = 14
        layer.shadowOffset = .zero

        NSLayoutConstraint.activate([
            highlightView.topAnchor.constraint(equalTo: topAnchor),
            highlightView.bottomAnchor.constraint(equalTo: bottomAnchor),
            highlightView.leadingAnchor.constraint(equalTo: leadingAnchor),
            highlightView.trailingAnchor.constraint(equalTo: trailingAnchor),

            iconView.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconView.heightAnchor.constraint(equalToConstant: 40),

            titleLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 4),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),

            // Минимальная ширина, чтобы короткие подписи ("Поиск") не давали узкую кнопку
            widthAnchor.constraint(greaterThanOrEqualToConstant: 120),

            // Бейдж — на правом верхнем углу иконки
            badgeLabel.centerXAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 4),
            badgeLabel.centerYAnchor.constraint(equalTo: iconView.topAnchor, constant: 4),
            badgeLabel.heightAnchor.constraint(equalToConstant: 28),
            badgeLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 28)
        ])

        applyAppearance(animated: false)
    }

    private func applyAppearance(animated: Bool) {
        let changes = {
            let color = self.isSelectedTab ? PRTheme.brass : PRTheme.textSecondary
            self.iconView.tintColor = color
            self.titleLabel.textColor = color
            self.highlightView.backgroundColor = self.isSelectedTab ? PRTheme.surfaceFocused : .clear
        }
        if animated {
            UIView.animate(withDuration: 0.2, animations: changes)
        } else {
            changes()
        }
    }

    // MARK: - Focus Engine

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)

        if context.nextFocusedView === self {
            coordinator.addCoordinatedAnimations({
                self.transform = CGAffineTransform(scaleX: 1.08, y: 1.08)
                self.highlightView.layer.borderWidth = 2
                self.layer.shadowOpacity = 0.5
            }, completion: nil)
        } else if context.previouslyFocusedView === self {
            coordinator.addCoordinatedAnimations({
                self.transform = .identity
                self.highlightView.layer.borderWidth = 0
                self.layer.shadowOpacity = 0
            }, completion: nil)
        }
    }
}

/// Лейбл бейджа с горизонтальными отступами — чтобы "12" и "99+" не упирались в края
private final class PRBadgeLabel: UILabel {
    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + 14, height: size.height)
    }
}
