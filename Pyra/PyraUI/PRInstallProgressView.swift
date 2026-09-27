//
//  PRInstallProgressView.swift
//  Pyra
//  Created by Fauxly on 26.09.2026.

import UIKit

/// Панель хода операции над пакетом: цепочка шагов (Скачивание → Установка → Проверка → Готово)
/// и полоса прогресса под ними. Заменяет "голый" лог dpkg как основной индикатор —
/// сам лог остаётся доступен отдельно, по кнопке.
final class PRInstallProgressView: UIView {

    private enum StepState {
        case pending, active, done, failed
    }

    private final class StepView: UIStackView {
        let iconView = UIImageView()
        let titleLabel = UILabel()

        init(title: String) {
            super.init(frame: .zero)
            axis = .horizontal
            spacing = 12
            alignment = .center

            iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 30, weight: .semibold)
            iconView.setContentHuggingPriority(.required, for: .horizontal)
            titleLabel.text = title
            titleLabel.font = UIFont.systemFont(ofSize: 26, weight: .semibold)

            addArrangedSubview(iconView)
            addArrangedSubview(titleLabel)
        }

        required init(coder: NSCoder) {
            fatalError("init(coder:) не поддерживается")
        }

        func apply(_ state: StepState) {
            iconView.layer.removeAnimation(forKey: "pulse")
            switch state {
            case .pending:
                iconView.image = UIImage(systemName: "circle")
                iconView.tintColor = PRTheme.textSecondary.withAlphaComponent(0.6)
                titleLabel.textColor = PRTheme.textSecondary
            case .active:
                iconView.image = UIImage(systemName: "circle.dotted")
                iconView.tintColor = PRTheme.brass
                titleLabel.textColor = PRTheme.textPrimary
                // Мягкая пульсация — видно, что шаг идёт, а не завис
                let pulse = CABasicAnimation(keyPath: "opacity")
                pulse.fromValue = 1
                pulse.toValue = 0.3
                pulse.duration = 0.7
                pulse.autoreverses = true
                pulse.repeatCount = .infinity
                iconView.layer.add(pulse, forKey: "pulse")
            case .done:
                iconView.image = UIImage(systemName: "checkmark.circle.fill")
                iconView.tintColor = PRTheme.teal
                titleLabel.textColor = PRTheme.textPrimary
            case .failed:
                iconView.image = UIImage(systemName: "xmark.circle.fill")
                iconView.tintColor = UIColor(red: 0xE0 / 255, green: 0x6C / 255, blue: 0x62 / 255, alpha: 1)
                titleLabel.textColor = PRTheme.textPrimary
            }
        }
    }

    private let stepsStack = UIStackView()
    private let progressBar = UIProgressView(progressViewStyle: .default)
    private var stepViews: [StepView] = []

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = PRTheme.surface.withAlphaComponent(0.85)
        layer.cornerRadius = 24
        layer.cornerCurve = .continuous

        stepsStack.axis = .horizontal
        stepsStack.spacing = 56
        stepsStack.alignment = .center
        stepsStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stepsStack)

        progressBar.progressTintColor = PRTheme.brass
        progressBar.trackTintColor = PRTheme.ink
        progressBar.layer.cornerRadius = 4
        progressBar.clipsToBounds = true
        progressBar.translatesAutoresizingMaskIntoConstraints = false
        addSubview(progressBar)

        NSLayoutConstraint.activate([
            stepsStack.topAnchor.constraint(equalTo: topAnchor, constant: 26),
            stepsStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 36),
            stepsStack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -36),

            progressBar.topAnchor.constraint(equalTo: stepsStack.bottomAnchor, constant: 22),
            progressBar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 36),
            progressBar.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -36),
            progressBar.heightAnchor.constraint(equalToConstant: 8),
            progressBar.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -26)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) не поддерживается")
    }

    /// Задать новый набор шагов (все в ожидании, прогресс в ноль)
    func setSteps(_ titles: [String]) {
        stepViews.forEach { $0.removeFromSuperview() }
        stepViews = titles.map { StepView(title: $0) }
        stepViews.forEach {
            stepsStack.addArrangedSubview($0)
            $0.apply(.pending)
        }
        progressBar.setProgress(0, animated: false)
    }

    /// Шаг index в работе, все до него — выполнены
    func setActive(_ index: Int) {
        for (i, step) in stepViews.enumerated() {
            step.apply(i < index ? .done : (i == index ? .active : .pending))
        }
        let total = max(stepViews.count - 1, 1)
        progressBar.setProgress(Float(index) / Float(total), animated: true)
    }

    /// Все шаги выполнены
    func finish() {
        stepViews.forEach { $0.apply(.done) }
        progressBar.setProgress(1, animated: true)
    }

    /// Текущий активный шаг провалился
    func fail() {
        if let index = stepViews.firstIndex(where: { $0.iconView.layer.animation(forKey: "pulse") != nil }) {
            stepViews[index].apply(.failed)
        } else {
            stepViews.last?.apply(.failed)
        }
    }
}
