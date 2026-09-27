//
//  PRCardCell.swift
//  Pyra
//  Created by Fauxly on 27.09.2026.

import UIKit

/// База для карточек во вкладках (категории, источники, обновления): тёмная подложка,
/// скругление, в фокусе — подъём, латунная рамка и свечение. Наследники кладут своё
/// содержимое в `contentView`.
class PRCardCell: UICollectionViewCell {

    /// Во сколько раз карточка увеличивается в фокусе (широким карточкам — поменьше)
    var focusScale: CGFloat = 1.06

    override init(frame: CGRect) {
        super.init(frame: frame)

        contentView.backgroundColor = PRTheme.surface
        contentView.layer.cornerRadius = 24
        contentView.layer.cornerCurve = .continuous
        contentView.layer.borderColor = PRTheme.brass.cgColor
        contentView.layer.borderWidth = 0
        contentView.clipsToBounds = true

        layer.shadowColor = PRTheme.brass.cgColor
        layer.shadowOpacity = 0
        layer.shadowRadius = 18
        layer.shadowOffset = .zero
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) не поддерживается")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        transform = .identity
        contentView.layer.borderWidth = 0
        layer.shadowOpacity = 0
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        if context.nextFocusedItem === self {
            coordinator.addCoordinatedAnimations({
                self.transform = CGAffineTransform(scaleX: self.focusScale, y: self.focusScale)
                self.contentView.layer.borderWidth = 3
                self.layer.shadowOpacity = 0.5
            }, completion: nil)
        } else if context.previouslyFocusedItem === self {
            coordinator.addCoordinatedAnimations({
                self.transform = .identity
                self.contentView.layer.borderWidth = 0
                self.layer.shadowOpacity = 0
            }, completion: nil)
        }
    }

    // MARK: - Общие мелочи для наследников

    /// Иконка пакета/источника по URL с плейсхолдером и отменой при переиспользовании
    static func loadImage(_ urlString: String?, into imageView: UIImageView, placeholder: String, task: inout Task<Void, Never>?) {
        task?.cancel()
        imageView.contentMode = .center
        imageView.image = UIImage(systemName: placeholder)
        guard let urlString, !urlString.isEmpty else { return }

        task = Task { [weak imageView] in
            let image = await PRImageCache.shared.image(for: urlString)
            guard !Task.isCancelled, let image else { return }
            await MainActor.run {
                imageView?.contentMode = .scaleAspectFill
                imageView?.image = image
            }
        }
    }

    static func makeIconView(size: CGFloat, cornerRadius: CGFloat) -> UIImageView {
        let imageView = UIImageView()
        imageView.backgroundColor = PRTheme.surfaceFocused
        imageView.tintColor = PRTheme.textSecondary
        imageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: size * 0.4, weight: .medium)
        imageView.layer.cornerRadius = cornerRadius
        imageView.layer.cornerCurve = .continuous
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.widthAnchor.constraint(equalToConstant: size).isActive = true
        imageView.heightAnchor.constraint(equalToConstant: size).isActive = true
        return imageView
    }

    static func makeLabel(size: CGFloat, weight: UIFont.Weight, color: UIColor) -> UILabel {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: size, weight: weight)
        label.textColor = color
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }
}

/// Лейбл-плашка с отступами (версии в карточках обновлений, счётчики и т.п.)
final class PRPillLabel: UILabel {
    var insets = UIEdgeInsets(top: 4, left: 14, bottom: 4, right: 14)

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + insets.left + insets.right, height: size.height + insets.top + insets.bottom)
    }
}
