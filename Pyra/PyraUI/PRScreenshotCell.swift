//
//  PRScreenshotCell.swift
//  Pyra
//  Created by Fauxly on 27.09.2026.

import UIKit

/// Скриншот пакета в горизонтальной ленте на экране пакета. Фокусируемый — чтобы ленту
/// можно было листать пультом; в фокусе чуть увеличивается с латунной рамкой.
final class PRScreenshotCell: UICollectionViewCell {

    static let reuseIdentifier = "PRScreenshotCell"

    private let imageView = UIImageView()
    private var loadTask: Task<Void, Never>?

    override init(frame: CGRect) {
        super.init(frame: frame)

        contentView.backgroundColor = PRTheme.surface
        contentView.layer.cornerRadius = 18
        contentView.layer.cornerCurve = .continuous
        contentView.layer.borderColor = PRTheme.brass.cgColor
        contentView.clipsToBounds = true

        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.4
        layer.shadowRadius = 14
        layer.shadowOffset = CGSize(width: 0, height: 8)

        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) не поддерживается")
    }

    func configure(with url: URL) {
        loadTask?.cancel()
        imageView.image = nil
        loadTask = Task { [weak self] in
            let image = await PRImageCache.shared.image(for: url.absoluteString)
            guard !Task.isCancelled, let image else { return }
            await MainActor.run {
                guard let self else { return }
                UIView.transition(with: self.imageView, duration: 0.25, options: .transitionCrossDissolve) {
                    self.imageView.image = image
                }
            }
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        loadTask?.cancel()
        loadTask = nil
        imageView.image = nil
        transform = .identity
        contentView.layer.borderWidth = 0
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        if context.nextFocusedItem === self {
            coordinator.addCoordinatedAnimations({
                self.transform = CGAffineTransform(scaleX: 1.06, y: 1.06)
                self.contentView.layer.borderWidth = 3
            }, completion: nil)
        } else if context.previouslyFocusedItem === self {
            coordinator.addCoordinatedAnimations({
                self.transform = .identity
                self.contentView.layer.borderWidth = 0
            }, completion: nil)
        }
    }
}
