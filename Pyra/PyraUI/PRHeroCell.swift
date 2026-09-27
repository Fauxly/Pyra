//
//  PRHeroCell.swift
//  Pyra
//  Created by Fauxly on 26.09.2026.

import UIKit

/// View, у которой корневой слой — сразу CAGradientLayer. Градиент тянется вместе с view
/// через Auto Layout сам, без ручного обновления frame слоя в layoutSubviews.
final class PRGradientView: UIView {
    override class var layerClass: AnyClass { CAGradientLayer.self }
    var gradientLayer: CAGradientLayer { layer as! CAGradientLayer }
}

/// Лейбл-"таблетка" с внутренними отступами — для тега категории на hero-карточке.
private final class PRHeroTagLabel: UILabel {
    private let insets = UIEdgeInsets(top: 6, left: 16, bottom: 6, right: 16)

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + insets.left + insets.right,
                      height: size.height + insets.top + insets.bottom)
    }
}

/// Большая карточка верхней карусели главной — в духе "витрины" приложения Apple TV:
/// размытый цветной фон из иконки самого пакета, крупная иконка справа, текст слева.
/// Не плоская плитка, а объёмный баннер: в фокусе приподнимается, получает латунную
/// рамку и параллакс иконки от тачпада пульта.
final class PRHeroCell: UICollectionViewCell {

    static let reuseIdentifier = "PRHeroCell"

    private static let cornerRadius: CGFloat = 36

    // Фон (снизу вверх): запасной градиент → размытая иконка → затемнение для читаемости текста
    private let fallbackGradient = PRGradientView()
    private let backdropView = UIImageView()
    private let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
    private let shadeView = PRGradientView()

    private let iconContainer = UIView()
    private let iconView = UIImageView()

    private let textStack = UIStackView()
    private let tagLabel = PRHeroTagLabel()
    private let titleLabel = UILabel()
    private let metaLabel = UILabel()
    private let descriptionLabel = UILabel()
    private let moreLabel = UILabel()

    private var iconLoadTask: Task<Void, Never>?
    private var parallaxEffect: UIMotionEffectGroup?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) не поддерживается")
    }

    // MARK: - Вёрстка

    private func setupViews() {
        contentView.backgroundColor = PRTheme.surface
        contentView.layer.cornerRadius = Self.cornerRadius
        contentView.layer.cornerCurve = .continuous
        contentView.layer.borderColor = PRTheme.brass.cgColor
        contentView.layer.borderWidth = 0
        contentView.clipsToBounds = true

        // Тень — на слое самой ячейки: contentView обрезан по скруглению и срезал бы её
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.45
        layer.shadowRadius = 24
        layer.shadowOffset = CGSize(width: 0, height: 14)

        // Запасной фон, пока иконка не загрузилась (или если её нет вовсе)
        fallbackGradient.gradientLayer.colors = [
            PRTheme.teal.withAlphaComponent(0.55).cgColor,
            PRTheme.surface.cgColor,
            PRTheme.ink.cgColor
        ]
        fallbackGradient.gradientLayer.startPoint = CGPoint(x: 1, y: 0)
        fallbackGradient.gradientLayer.endPoint = CGPoint(x: 0, y: 1)

        // Иконка, растянутая на всю карточку и размытая, даёт "цвет пакета" на фоне —
        // как обложка фильма за баннером в приложении TV
        backdropView.contentMode = .scaleAspectFill
        backdropView.clipsToBounds = true
        backdropView.alpha = 0.9

        // Слева почти непрозрачное затемнение под текст, справа — прозрачно, чтобы цвет жил
        shadeView.gradientLayer.colors = [
            PRTheme.ink.withAlphaComponent(0.92).cgColor,
            PRTheme.ink.withAlphaComponent(0.6).cgColor,
            PRTheme.ink.withAlphaComponent(0.05).cgColor
        ]
        shadeView.gradientLayer.locations = [0, 0.5, 1]
        shadeView.gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        shadeView.gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)

        for background in [fallbackGradient, backdropView, blurView, shadeView] as [UIView] {
            background.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(background)
            NSLayoutConstraint.activate([
                background.topAnchor.constraint(equalTo: contentView.topAnchor),
                background.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
                background.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                background.trailingAnchor.constraint(equalTo: contentView.trailingAnchor)
            ])
        }

        // Крупная иконка справа — отдельный контейнер ради тени (сама иконка обрезана скруглением)
        iconContainer.layer.shadowColor = UIColor.black.cgColor
        iconContainer.layer.shadowOpacity = 0.5
        iconContainer.layer.shadowRadius = 30
        iconContainer.layer.shadowOffset = CGSize(width: 0, height: 16)
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(iconContainer)

        iconView.clipsToBounds = true
        iconView.layer.cornerRadius = 64
        iconView.layer.cornerCurve = .continuous
        iconView.backgroundColor = PRTheme.surfaceFocused
        iconView.tintColor = PRTheme.textSecondary
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 110, weight: .regular)
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.addSubview(iconView)

        // Текстовый блок слева
        tagLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        tagLabel.textColor = PRTheme.ink
        tagLabel.backgroundColor = PRTheme.teal
        tagLabel.layer.cornerRadius = 14
        tagLabel.clipsToBounds = true

        titleLabel.font = UIFont.systemFont(ofSize: 64, weight: .heavy)
        titleLabel.textColor = PRTheme.textPrimary
        titleLabel.numberOfLines = 2
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.6

        metaLabel.font = UIFont.systemFont(ofSize: 26, weight: .medium)
        metaLabel.textColor = PRTheme.textSecondary
        metaLabel.numberOfLines = 1

        descriptionLabel.font = UIFont.systemFont(ofSize: 28, weight: .regular)
        descriptionLabel.textColor = PRTheme.textPrimary.withAlphaComponent(0.85)
        descriptionLabel.numberOfLines = 3

        moreLabel.font = UIFont.systemFont(ofSize: 26, weight: .semibold)
        moreLabel.textColor = PRTheme.brass

        textStack.axis = .vertical
        textStack.alignment = .leading
        textStack.spacing = 14
        for label in [tagLabel, titleLabel, metaLabel, descriptionLabel, moreLabel] as [UILabel] {
            textStack.addArrangedSubview(label)
        }
        textStack.setCustomSpacing(8, after: titleLabel)
        textStack.setCustomSpacing(26, after: descriptionLabel)
        textStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(textStack)

        NSLayoutConstraint.activate([
            iconContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -90),
            iconContainer.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconContainer.widthAnchor.constraint(equalToConstant: 300),
            iconContainer.heightAnchor.constraint(equalToConstant: 300),

            iconView.topAnchor.constraint(equalTo: iconContainer.topAnchor),
            iconView.bottomAnchor.constraint(equalTo: iconContainer.bottomAnchor),
            iconView.leadingAnchor.constraint(equalTo: iconContainer.leadingAnchor),
            iconView.trailingAnchor.constraint(equalTo: iconContainer.trailingAnchor),

            textStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 80),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: iconContainer.leadingAnchor, constant: -70),
            textStack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            textStack.topAnchor.constraint(greaterThanOrEqualTo: contentView.topAnchor, constant: 40),
            textStack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -40)
        ])
    }

    // MARK: - Данные

    func configure(with package: PRPackage) {
        titleLabel.text = package.name

        let section = package.section.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasSection = !section.isEmpty && section.lowercased() != "unknown"
        tagLabel.text = hasSection ? section.uppercased() : nil
        tagLabel.isHidden = !hasSection

        var meta: [String] = []
        if let author = Self.cleanAuthor(package.author) { meta.append(author) }
        if !package.version.isEmpty { meta.append("v\(package.version)") }
        metaLabel.text = meta.joined(separator: "  ·  ")
        metaLabel.isHidden = meta.isEmpty

        let description = package.description.trimmingCharacters(in: .whitespacesAndNewlines)
        descriptionLabel.text = description
        descriptionLabel.isHidden = description.isEmpty

        moreLabel.text = "DASHBOARD_HERO_MORE".localized + "  ›"

        showPlaceholderIcon()

        iconLoadTask?.cancel()
        guard let iconURLString = package.iconURL, !iconURLString.isEmpty else { return }

        iconLoadTask = Task { [weak self] in
            let image = await PRImageCache.shared.image(for: iconURLString)
            // Ячейку могли переиспользовать под другой пакет, пока шла загрузка
            guard !Task.isCancelled, let image else { return }

            await MainActor.run {
                guard let self else { return }
                UIView.transition(with: self.contentView, duration: 0.35, options: .transitionCrossDissolve) {
                    self.iconView.contentMode = .scaleAspectFill
                    self.iconView.image = image
                    self.backdropView.image = image
                }
            }
        }
    }

    private func showPlaceholderIcon() {
        iconView.contentMode = .center
        iconView.image = UIImage(systemName: "shippingbox")
        backdropView.image = nil
    }

    /// Поле Author в control-файле обычно вида "Имя <mail@host>" — почту на баннере не показываем.
    private static func cleanAuthor(_ raw: String?) -> String? {
        guard var author = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !author.isEmpty else { return nil }
        if let bracket = author.firstIndex(of: "<") {
            author = String(author[..<bracket]).trimmingCharacters(in: .whitespaces)
        }
        return author.isEmpty ? nil : author
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        iconLoadTask?.cancel()
        iconLoadTask = nil

        showPlaceholderIcon()
        titleLabel.text = nil
        metaLabel.text = nil
        descriptionLabel.text = nil
        tagLabel.text = nil

        removeParallax()
        transform = .identity
        contentView.layer.borderWidth = 0
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.45
    }

    // MARK: - Focus Engine

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)

        if context.nextFocusedItem === self {
            addParallax()
            coordinator.addCoordinatedAnimations({
                self.transform = CGAffineTransform(scaleX: 1.03, y: 1.03)
                self.contentView.layer.borderWidth = 3
                self.layer.shadowColor = PRTheme.brass.cgColor
                self.layer.shadowOpacity = 0.5
                self.iconContainer.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
            }, completion: nil)
        } else if context.previouslyFocusedItem === self {
            removeParallax()
            coordinator.addCoordinatedAnimations({
                self.transform = .identity
                self.contentView.layer.borderWidth = 0
                self.layer.shadowColor = UIColor.black.cgColor
                self.layer.shadowOpacity = 0.45
                self.iconContainer.transform = .identity
            }, completion: nil)
        }
    }

    /// Параллакс иконки от касания тачпада — пока карточка в фокусе, иконка чуть "плавает"
    /// относительно фона, как постеры в системных приложениях tvOS.
    private func addParallax() {
        guard parallaxEffect == nil else { return }

        let horizontal = UIInterpolatingMotionEffect(keyPath: "center.x", type: .tiltAlongHorizontalAxis)
        horizontal.minimumRelativeValue = -18
        horizontal.maximumRelativeValue = 18

        let vertical = UIInterpolatingMotionEffect(keyPath: "center.y", type: .tiltAlongVerticalAxis)
        vertical.minimumRelativeValue = -12
        vertical.maximumRelativeValue = 12

        let group = UIMotionEffectGroup()
        group.motionEffects = [horizontal, vertical]
        iconContainer.addMotionEffect(group)
        parallaxEffect = group
    }

    private func removeParallax() {
        guard let parallaxEffect else { return }
        iconContainer.removeMotionEffect(parallaxEffect)
        self.parallaxEffect = nil
    }
}
