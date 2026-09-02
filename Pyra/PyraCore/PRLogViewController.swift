//
//  PRLogViewController.swift
//  Pyra
//

import UIKit

final class PRLogViewController: UIViewController {

    private let textView = UITextView()
    private let clearButton = UIButton(type: .system)

    // Показываем только "хвост" лога — иначе гигантский файл за долгую сессию
    // будет тормозить UITextView при рендере
    private let maxDisplayedCharacters = 30000

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "SETTINGS_DIAGNOSTIC_LOG".localized
        view.backgroundColor = PRTheme.ink
        setupUI()
        reloadLog()
    }

    // Фокус сразу на текст лога — та же логика, что и в карточке пакета: иначе Focus Engine
    // может сам выбрать кнопку "Очистить" при входе на экран, а не то, что реально нужно читать.
    override var preferredFocusEnvironments: [UIFocusEnvironment] {
        [textView]
    }

    private func setupUI() {
        clearButton.backgroundColor = PRTheme.surface
        clearButton.layer.cornerRadius = 12
        clearButton.frame = CGRect(x: 60, y: 60, width: 240, height: 64)
        clearButton.addTarget(self, action: #selector(clearTapped), for: .primaryActionTriggered)
        view.addSubview(clearButton)

        // Явный UILabel вместо setTitle — на этой сборке tvOS встроенный titleLabel
        // кнопки ненадёжно рисуется (та же история, что с иконками/клавиатурой раньше).
        let clearLabel = UILabel()
        clearLabel.text = "SETTINGS_LOG_CLEAR".localized
        clearLabel.textColor = PRTheme.textPrimary
        clearLabel.font = UIFont.systemFont(ofSize: 24, weight: .medium)
        clearLabel.textAlignment = .center
        clearLabel.isUserInteractionEnabled = false
        clearLabel.translatesAutoresizingMaskIntoConstraints = false
        clearButton.addSubview(clearLabel)
        NSLayoutConstraint.activate([
            clearLabel.centerXAnchor.constraint(equalTo: clearButton.centerXAnchor),
            clearLabel.centerYAnchor.constraint(equalTo: clearButton.centerYAnchor)
        ])

        textView.frame = CGRect(x: 60, y: 150, width: view.bounds.width - 120, height: view.bounds.height - 210)
        textView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        textView.backgroundColor = PRTheme.surface
        textView.textColor = PRTheme.textPrimary
        textView.font = UIFont.monospacedSystemFont(ofSize: 20, weight: .regular)
        textView.isSelectable = true
        textView.isScrollEnabled = true
        textView.showsVerticalScrollIndicator = true
        textView.layer.cornerRadius = 12
        textView.textContainerInset = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        view.addSubview(textView)
    }

    private func reloadLog() {
        let full = PRLogger.readLog()
        let tail = String(full.suffix(maxDisplayedCharacters))
        textView.text = tail.isEmpty ? "SETTINGS_LOG_EMPTY".localized : tail

        // Прокручиваем в конец — самые свежие записи внизу
        let bottom = NSRange(location: (textView.text as NSString).length, length: 0)
        textView.scrollRangeToVisible(bottom)
    }

    @objc private func clearTapped() {
        PRLogger.clearLog()
        reloadLog()
    }
}
