//
//  PRSectionHeaderView.swift
//  Pyra
//
//  Created by Fauxly on 06.07.2026.


import UIKit

/// Заголовок ряда на главной: иконка источника (CydiaIcon.png) + название.
/// Без иконки (или пока она грузится) — только текст, без пустого места слева.
final class PRSectionHeaderView: UICollectionReusableView {

    static let reuseIdentifier = "PRSectionHeaderView"

    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let stack = UIStackView()
    private var iconLoadTask: Task<Void, Never>?
    private var leadingConstraint: NSLayoutConstraint!

    /// Отступ слева — на главной 40 (ряды с внутренними отступами плиток), в сетках вкладок 60
    var leadingInset: CGFloat = 40 {
        didSet { leadingConstraint.constant = leadingInset }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) не поддерживается")
    }

    private func setupViews() {
        iconView.contentMode = .scaleAspectFill
        iconView.layer.cornerRadius = 10
        iconView.layer.cornerCurve = .continuous
        iconView.clipsToBounds = true
        iconView.isHidden = true

        titleLabel.font = UIFont.systemFont(ofSize: 28, weight: .bold)
        titleLabel.textColor = PRTheme.textPrimary

        stack.axis = .horizontal
        stack.spacing = 14
        stack.alignment = .center
        stack.addArrangedSubview(iconView)
        stack.addArrangedSubview(titleLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        leadingConstraint = stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: leadingInset)

        NSLayoutConstraint.activate([
            leadingConstraint,
            iconView.widthAnchor.constraint(equalToConstant: 44),
            iconView.heightAnchor.constraint(equalToConstant: 44),

            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -40),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    func configure(title: String, iconURL: URL? = nil) {
        titleLabel.text = title
        iconView.image = nil
        iconView.isHidden = true

        iconLoadTask?.cancel()
        guard let iconURL else { return }

        iconLoadTask = Task { [weak self] in
            let image = await PRImageCache.shared.image(for: iconURL.absoluteString)
            guard !Task.isCancelled, let image else { return }
            await MainActor.run {
                self?.iconView.image = image
                self?.iconView.isHidden = false
            }
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        iconLoadTask?.cancel()
        iconLoadTask = nil
        iconView.image = nil
        iconView.isHidden = true
    }
}
