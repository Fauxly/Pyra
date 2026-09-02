//
//  PRAboutViewController.swift
//  Pyra
//

import UIKit

final class PRAboutViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "SETTINGS_ABOUT".localized
        view.backgroundColor = PRTheme.ink
        setupUI()
    }

    private func setupUI() {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 24
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 80),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 100),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -100)
        ])

        let titleLabel = makeLabel("Pyra", font: .boldSystemFont(ofSize: 48), color: PRTheme.brass)
        stack.addArrangedSubview(titleLabel)
        stack.setCustomSpacing(40, after: titleLabel)

        for (label, value) in infoRows() {
            stack.addArrangedSubview(makeInfoRow(label: label, value: value))
        }

        let creditLabel = makeLabel(
            "SETTINGS_ABOUT_CREDIT".localized,
            font: .systemFont(ofSize: 20, weight: .regular),
            color: PRTheme.textSecondary
        )
        creditLabel.numberOfLines = 0
        stack.addArrangedSubview(creditLabel)
        stack.setCustomSpacing(40, after: stack.arrangedSubviews[stack.arrangedSubviews.count - 2])
    }

    private func infoRows() -> [(String, String)] {
        let bundleVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"

        return [
            ("SETTINGS_ABOUT_VERSION".localized, "\(bundleVersion) (\(buildNumber))"),
            ("SETTINGS_ABOUT_DEVICE".localized, deviceModelIdentifier()),
            ("SETTINGS_ABOUT_TVOS".localized, UIDevice.current.systemVersion),
            ("SETTINGS_ABOUT_BOOTSTRAP".localized, PRPathManager.shared.isRootless ? "Rootless" : "Rootful")
        ]
    }

    private func makeInfoRow(label: String, value: String) -> UIView {
        let container = UIStackView()
        container.axis = .horizontal
        container.spacing = 16

        let labelView = makeLabel(label, font: .systemFont(ofSize: 24, weight: .regular), color: PRTheme.textSecondary)
        labelView.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let valueView = makeLabel(value, font: .systemFont(ofSize: 24, weight: .semibold), color: PRTheme.textPrimary)
        valueView.setContentHuggingPriority(.required, for: .horizontal)

        container.addArrangedSubview(labelView)
        container.addArrangedSubview(valueView)
        return container
    }

    private func makeLabel(_ text: String, font: UIFont, color: UIColor) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = font
        label.textColor = color
        return label
    }

    /// Идентификатор модели устройства (например "AppleTV6,2") через uname() — публичного API
    /// вроде UIDevice.current.model, различающего конкретные модели Apple TV, попросту нет.
    private func deviceModelIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let mirror = Mirror(reflecting: systemInfo.machine)
        let identifier = mirror.children.reduce("") { partial, element in
            guard let value = element.value as? Int8, value != 0 else { return partial }
            return partial + String(UnicodeScalar(UInt8(value)))
        }
        return identifier.isEmpty ? "—" : identifier
    }
}
