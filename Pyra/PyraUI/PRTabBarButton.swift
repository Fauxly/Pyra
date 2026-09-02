//
//  PRTabBarButton.swift
//  Pyra
//  Created by Fauxly

import UIKit

/// Кнопка для кастомного таб-бара — латунная подсветка фокуса в том же визуальном языке,
/// что и PRPackageCell, вместо стандартного system-стиля UIButton.
final class PRTabBarButton: UIButton {

    var isSelectedTab: Bool = false {
        didSet { applyAppearance() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) не поддерживается")
    }

    private func setup() {
        layer.cornerRadius = 28
        layer.borderWidth = 0
        layer.borderColor = PRTheme.brass.cgColor

        layer.shadowColor = PRTheme.brass.cgColor
        layer.shadowOpacity = 0
        layer.shadowRadius = 10
        layer.shadowOffset = .zero

        titleLabel?.font = UIFont.systemFont(ofSize: 28, weight: .semibold)
        contentEdgeInsets = UIEdgeInsets(top: 0, left: 28, bottom: 0, right: 28)

        applyAppearance()
    }

    private func applyAppearance() {
        backgroundColor = isSelectedTab ? PRTheme.surfaceFocused : .clear
        tintColor = isSelectedTab ? PRTheme.brass : PRTheme.textSecondary
        setTitleColor(isSelectedTab ? PRTheme.brass : PRTheme.textSecondary, for: .normal)
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)

        if context.nextFocusedView === self {
            coordinator.addCoordinatedAnimations({
                self.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
                self.layer.borderWidth = 2
                self.layer.shadowOpacity = 0.5
            }, completion: nil)
        } else if context.previouslyFocusedView === self {
            coordinator.addCoordinatedAnimations({
                self.transform = .identity
                self.layer.borderWidth = 0
                self.layer.shadowOpacity = 0
            }, completion: nil)
        }
    }
}
