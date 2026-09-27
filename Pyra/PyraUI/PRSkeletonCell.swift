//
//  PRSkeletonCell.swift
//  Pyra
//  Created by Fauxly on 26.09.2026.

import UIKit

/// Заглушка плитки на время загрузки каталога: тёмная карточка с бегущим бликом.
/// Показывает форму будущего экрана вместо пустоты, пока репозитории отвечают.
final class PRSkeletonCell: UICollectionViewCell {

    static let reuseIdentifier = "PRSkeletonCell"

    private let shimmer = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)

        contentView.backgroundColor = PRTheme.surface
        contentView.layer.cornerRadius = 16
        contentView.layer.cornerCurve = .continuous
        contentView.clipsToBounds = true

        let highlight = PRTheme.surfaceFocused.withAlphaComponent(0.9).cgColor
        let clear = PRTheme.surface.withAlphaComponent(0).cgColor
        shimmer.colors = [clear, highlight, clear]
        shimmer.locations = [0, 0.5, 1]
        shimmer.startPoint = CGPoint(x: 0, y: 0.5)
        shimmer.endPoint = CGPoint(x: 1, y: 0.5)
        contentView.layer.addSublayer(shimmer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) не поддерживается")
    }

    /// Скелетоны не фокусируются — нажимать там нечего
    override var canBecomeFocused: Bool { false }

    /// Скругление больше для заглушки баннера
    func configure(cornerRadius: CGFloat) {
        contentView.layer.cornerRadius = cornerRadius
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let width = contentView.bounds.width
        shimmer.frame = CGRect(x: -width, y: 0, width: width * 3, height: contentView.bounds.height)
        startAnimating()
    }

    private func startAnimating() {
        guard shimmer.animation(forKey: "shimmer") == nil else { return }
        let move = CABasicAnimation(keyPath: "transform.translation.x")
        move.fromValue = -contentView.bounds.width
        move.toValue = contentView.bounds.width
        move.duration = 1.4
        move.repeatCount = .infinity
        shimmer.add(move, forKey: "shimmer")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        shimmer.removeAllAnimations()
        contentView.layer.cornerRadius = 16
    }
}
