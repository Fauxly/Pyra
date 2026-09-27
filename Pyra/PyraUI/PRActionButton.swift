//
//  PRActionButton.swift
//  Pyra
//  Created by Fauxly on 26.09.2026.

import UIKit

/// Крупная кнопка действия в стиле Pyra (Установить / Обновить / Удалить / Лог).
/// Тип .custom (через init(frame:)) — без системного фокус-эффекта tvOS, фокус рисуем сами.
final class PRActionButton: UIButton {

    enum Style {
        case primary      // латунь — установить/обновить
        case destructive  // приглушённый красный — удалить
        case secondary    // тёмная подложка — второстепенные действия
    }

    var style: Style = .primary {
        didSet { applyStyle() }
    }

    private static let destructiveColor = UIColor(red: 0xC2 / 255, green: 0x55 / 255, blue: 0x4D / 255, alpha: 1)

    override init(frame: CGRect) {
        super.init(frame: frame)

        layer.cornerRadius = 22
        layer.cornerCurve = .continuous
        layer.shadowOpacity = 0
        layer.shadowRadius = 18
        layer.shadowOffset = CGSize(width: 0, height: 6)

        titleLabel?.font = UIFont.systemFont(ofSize: 28, weight: .bold)
        contentEdgeInsets = UIEdgeInsets(top: 0, left: 44, bottom: 0, right: 44)
        imageEdgeInsets = UIEdgeInsets(top: 0, left: -10, bottom: 0, right: 10)
        adjustsImageWhenHighlighted = false
        adjustsImageWhenDisabled = false

        applyStyle()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) не поддерживается")
    }

    override var isEnabled: Bool {
        didSet { alpha = isEnabled ? 1 : 0.45 }
    }

    private func applyStyle() {
        let background: UIColor
        let foreground: UIColor
        switch style {
        case .primary:
            background = PRTheme.brass
            foreground = PRTheme.ink
        case .destructive:
            background = Self.destructiveColor
            foreground = .white
        case .secondary:
            background = PRTheme.surfaceFocused
            foreground = PRTheme.textPrimary
        }
        backgroundColor = background
        tintColor = foreground
        setTitleColor(foreground, for: .normal)
        setTitleColor(foreground, for: .disabled)
        layer.shadowColor = background.cgColor
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)

        if context.nextFocusedView === self {
            coordinator.addCoordinatedAnimations({
                self.transform = CGAffineTransform(scaleX: 1.08, y: 1.08)
                self.layer.shadowOpacity = 0.6
            }, completion: nil)
        } else if context.previouslyFocusedView === self {
            coordinator.addCoordinatedAnimations({
                self.transform = .identity
                self.layer.shadowOpacity = 0
            }, completion: nil)
        }
    }
}
