//
//  PRAddRepositoryViewController.swift
//  Pyra
//  Created by Fauxly on 06.07.2026.

import UIKit

/// Настоящий UITextField вместо кастомной экранной клавиатуры. Раньше здесь стоял
/// UIAlertController.addTextField(), который зависал намертво при вызове клавиатуры — но
/// оказалось, что дело было именно в конкретном механизме показа клавиатуры у алертов на tvOS,
/// а не в системной клавиатуре вообще: обычный UITextField (как в PRSearchViewController)
/// работает нормально и синхронизируется с клавиатурой на айфоне через Apple TV Remote.
final class PRAddRepositoryViewController: UIViewController, UITextFieldDelegate {

    var onSubmit: ((String) -> Void)?

    private let titleLabel = UILabel()
    private let textField = UITextField()
    private let statusLabel = UILabel()
    private var addedCount = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = PRTheme.ink
        setupUI()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        textField.becomeFirstResponder()
    }

    private func setupUI() {
        titleLabel.text = "ADD_REPO_TITLE".localized
        titleLabel.textColor = PRTheme.textPrimary
        titleLabel.font = UIFont.systemFont(ofSize: 40, weight: .semibold)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 90),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 100),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -100)
        ])

        textField.text = "https://"
        textField.textColor = PRTheme.textPrimary
        textField.font = UIFont.systemFont(ofSize: 36, weight: .medium)
        textField.textAlignment = .center
        textField.backgroundColor = PRTheme.surface
        textField.layer.cornerRadius = 16
        textField.keyboardType = .URL
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .none
        textField.clearButtonMode = .whileEditing
        textField.returnKeyType = .done
        textField.delegate = self
        textField.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(textField)

        NSLayoutConstraint.activate([
            textField.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 50),
            textField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 200),
            textField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -200),
            textField.heightAnchor.constraint(equalToConstant: 80)
        ])

        // Показывает, сколько репозиториев уже добавлено в этой сессии — экран не закрывается
        // после каждого "Добавить", нужна обратная связь, что добавление реально произошло.
        statusLabel.textColor = PRTheme.brass
        statusLabel.font = UIFont.systemFont(ofSize: 24, weight: .medium)
        statusLabel.textAlignment = .center
        statusLabel.text = " "
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            statusLabel.topAnchor.constraint(equalTo: textField.bottomAnchor, constant: 24),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 100),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -100)
        ])

        let controlRow = UIStackView()
        controlRow.axis = .horizontal
        controlRow.spacing = 14
        controlRow.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(controlRow)

        controlRow.addArrangedSubview(makeControlButton(title: "ADD_REPO_DONE".localized, action: #selector(doneTapped), isPrimary: false))
        controlRow.addArrangedSubview(makeControlButton(title: "ADD_REPO_SUBMIT".localized, action: #selector(submitTapped), isPrimary: true))

        NSLayoutConstraint.activate([
            controlRow.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 50),
            controlRow.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }

    private func makeControlButton(title: String, action: Selector, isPrimary: Bool) -> UIButton {
        let button = UIButton(type: .system)
        button.backgroundColor = isPrimary ? PRTheme.brass : PRTheme.surface
        button.layer.cornerRadius = 12
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: 64).isActive = true

        // Явный UILabel вместо setTitle — на этой сборке tvOS встроенный titleLabel
        // кнопки ненадёжно рисуется.
        let label = UILabel()
        label.text = title
        label.textColor = isPrimary ? PRTheme.ink : PRTheme.textPrimary
        label.font = UIFont.systemFont(ofSize: 26, weight: .semibold)
        label.textAlignment = .center
        label.isUserInteractionEnabled = false
        label.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 24),
            label.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -24)
        ])

        button.addTarget(self, action: action, for: .primaryActionTriggered)
        return button
    }

    @objc private func doneTapped() {
        dismiss(animated: true)
    }

    @objc private func submitTapped() {
        let text = textField.text ?? ""
        guard text != "https://" && !text.isEmpty else { return }

        onSubmit?(text)
        addedCount += 1

        // Показываем короткий домен добавленного репозитория, а не весь URL — компактнее
        let host = URL(string: text)?.host ?? text
        statusLabel.text = String(format: "ADD_REPO_ADDED_STPRUS".localized, addedCount, host)

        // Сбрасываем поле для следующего URL — экран остаётся открытым
        textField.text = "https://"
    }

    // MARK: - UITextFieldDelegate

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        submitTapped()
        return true
    }
}
