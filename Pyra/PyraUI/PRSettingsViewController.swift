//
//  PRSettingsViewController.swift
//  Pyra
//  Created by Fauxly on 06.07.2026.

import UIKit

final class PRSettingsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    private enum Section: Int, CaseIterable {
        case language
        case general
        case storage
        case repositories
        case system
        case about
    }

    private let tableView = UITableView(frame: .zero, style: .plain)
    private let languages: [PRLanguage] = [.russian, .english]

    private let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "TAB_SETTINGS".localized
        view.backgroundColor = PRTheme.ink
        setupTableView()
    }

    private func setupTableView() {
        tableView.frame = view.bounds
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tableView.backgroundColor = .clear
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "LanguageCell")
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "StorageCell")
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "ResetRepositoriesCell")
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "AutoUpdateCell")
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "AboutCell")
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "SystemCell")
        view.addSubview(tableView)
    }

    // MARK: - UITableViewDataSource

    func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        sectionTitle(for: section)
    }
    
    private func sectionTitle(for section: Int) -> String? {
        switch Section(rawValue: section) {
        case .language: return "SETTINGS_LANGUAGE_SECTION".localized
        case .general: return "SETTINGS_GENERAL_SECTION".localized
        case .storage: return "SETTINGS_STORAGE_SECTION".localized
        case .repositories: return "SETTINGS_REPOSITORIES_SECTION".localized
        case .system: return "SETTINGS_SYSTEM_SECTION".localized
        case .about: return "SETTINGS_ABOUT_SECTION".localized
        case .none: return nil
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section) {
        case .language: return languages.count
        case .general: return 1
        case .storage: return 1
        case .repositories: return 1
        case .system: return 2
        case .about: return 3
        case .none: return 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section) {
        case .language:
            return languageCell(for: indexPath)
        case .general:
            return autoUpdateCell(for: indexPath)
        case .storage:
            return storageCell(for: indexPath)
        case .repositories:
            return resetRepositoriesCell(for: indexPath)
        case .system:
            return systemCell(for: indexPath)
        case .about:
            return aboutCell(for: indexPath)
        case .none:
            return UITableViewCell()
        }
    }

    private func languageCell(for indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "LanguageCell", for: indexPath)
        cell.backgroundColor = .clear

        let language = languages[indexPath.row]
        let isSelected = language == PRLocalizationManager.currentLanguage

        let focusBackground = UIView()
        focusBackground.backgroundColor = PRTheme.surfaceFocused
        focusBackground.layer.cornerRadius = 8
        cell.selectedBackgroundView = focusBackground

        if #available(tvOS 14.0, *) {
            var content = cell.defaultContentConfiguration()
            content.text = language.displayName
            content.textProperties.color = PRTheme.textPrimary
            content.textProperties.font = UIFont.systemFont(ofSize: 28, weight: .medium)
            cell.contentConfiguration = content
        } else {
            cell.textLabel?.text = language.displayName
            cell.textLabel?.textColor = PRTheme.textPrimary
        }

        cell.accessoryType = isSelected ? .checkmark : .none
        cell.tintColor = PRTheme.brass

        return cell
    }

    private func storageCell(for indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "StorageCell") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "StorageCell")
        cell.backgroundColor = .clear

        let focusBackground = UIView()
        focusBackground.backgroundColor = PRTheme.surfaceFocused
        focusBackground.layer.cornerRadius = 8
        cell.selectedBackgroundView = focusBackground

        let sizeText = byteFormatter.string(fromByteCount: PRFileManager.shared.cacheSize())

        if #available(tvOS 14.0, *) {
            var content = cell.defaultContentConfiguration()
            content.text = "SETTINGS_CLEAR_CACHE".localized
            content.secondaryText = sizeText
            content.textProperties.color = PRTheme.textPrimary
            content.textProperties.font = UIFont.systemFont(ofSize: 28, weight: .medium)
            content.secondaryTextProperties.color = PRTheme.textSecondary
            cell.contentConfiguration = content
        } else {
            cell.textLabel?.text = "SETTINGS_CLEAR_CACHE".localized
            cell.textLabel?.textColor = PRTheme.textPrimary
            cell.detailTextLabel?.text = sizeText
            cell.detailTextLabel?.textColor = PRTheme.textSecondary
        }

        return cell
    }

    private func resetRepositoriesCell(for indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ResetRepositoriesCell") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "ResetRepositoriesCell")
        cell.backgroundColor = .clear

        let focusBackground = UIView()
        focusBackground.backgroundColor = PRTheme.surfaceFocused
        focusBackground.layer.cornerRadius = 8
        cell.selectedBackgroundView = focusBackground

        let count = PRRepositoryManager.shared.repositories.count
        let countText = String(format: "SETTINGS_REPOSITORIES_COUNT".localized, count)

        if #available(tvOS 14.0, *) {
            var content = cell.defaultContentConfiguration()
            content.text = "SETTINGS_RESET_REPOSITORIES".localized
            content.secondaryText = countText
            content.textProperties.color = PRTheme.textPrimary
            content.textProperties.font = UIFont.systemFont(ofSize: 28, weight: .medium)
            content.secondaryTextProperties.color = PRTheme.textSecondary
            cell.contentConfiguration = content
        } else {
            cell.textLabel?.text = "SETTINGS_RESET_REPOSITORIES".localized
            cell.textLabel?.textColor = PRTheme.textPrimary
            cell.detailTextLabel?.text = countText
            cell.detailTextLabel?.textColor = PRTheme.textSecondary
        }

        return cell
    }

    private func autoUpdateCell(for indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "AutoUpdateCell") ?? UITableViewCell(style: .value1, reuseIdentifier: "AutoUpdateCell")
        cell.backgroundColor = .clear

        let focusBackground = UIView()
        focusBackground.backgroundColor = PRTheme.surfaceFocused
        focusBackground.layer.cornerRadius = 8
        cell.selectedBackgroundView = focusBackground

        let isOn = PRAppSettings.autoUpdateOnLaunch
        let stateText = isOn ? "SETTINGS_STATE_ON".localized : "SETTINGS_STATE_OFF".localized

        if #available(tvOS 14.0, *) {
            var content = cell.defaultContentConfiguration()
            content.text = "SETTINGS_AUTO_UPDATE".localized
            content.secondaryText = stateText
            content.textProperties.color = PRTheme.textPrimary
            content.textProperties.font = UIFont.systemFont(ofSize: 28, weight: .medium)
            content.secondaryTextProperties.color = isOn ? PRTheme.brass : PRTheme.textSecondary
            cell.contentConfiguration = content
        } else {
            cell.textLabel?.text = "SETTINGS_AUTO_UPDATE".localized
            cell.textLabel?.textColor = PRTheme.textPrimary
            cell.detailTextLabel?.text = stateText
            cell.detailTextLabel?.textColor = isOn ? PRTheme.brass : PRTheme.textSecondary
        }

        return cell
    }

    private func systemCell(for indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SystemCell") ?? UITableViewCell(style: .default, reuseIdentifier: "SystemCell")
        cell.backgroundColor = .clear
        
        let focusBackground = UIView()
        focusBackground.backgroundColor = PRTheme.surfaceFocused
        focusBackground.layer.cornerRadius = 8
        cell.selectedBackgroundView = focusBackground
        
        let title = indexPath.row == 0 ? "SETTINGS_RESPRING".localized : "SETTINGS_REBUILD_ICON_CACHE".localized
        
        if #available(tvOS 14.0, *) {
            var content = cell.defaultContentConfiguration()
            content.text = title
            content.textProperties.color = PRTheme.textPrimary
            content.textProperties.font = UIFont.systemFont(ofSize: 28, weight: .medium)
            cell.contentConfiguration = content
        } else {
            cell.textLabel?.text = title
            cell.textLabel?.textColor = PRTheme.textPrimary
        }
        
        return cell
    }
    
    private func aboutCell(for indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "AboutCell") ?? UITableViewCell(style: .default, reuseIdentifier: "AboutCell")
        cell.backgroundColor = .clear

        let focusBackground = UIView()
        focusBackground.backgroundColor = PRTheme.surfaceFocused
        focusBackground.layer.cornerRadius = 8
        cell.selectedBackgroundView = focusBackground

        let title: String
        switch indexPath.row {
        case 0: title = "SETTINGS_ABOUT".localized
        case 1: title = "SETTINGS_DIAGNOSTIC_LOG".localized
        default: title = "SETTINGS_CHECK_UPDATE".localized
        }

        if #available(tvOS 14.0, *) {
            var content = cell.defaultContentConfiguration()
            content.text = title
            content.textProperties.color = PRTheme.textPrimary
            content.textProperties.font = UIFont.systemFont(ofSize: 28, weight: .medium)
            cell.contentConfiguration = content
        } else {
            cell.textLabel?.text = title
            cell.textLabel?.textColor = PRTheme.textPrimary
        }

        return cell
    }

    // MARK: - UITableViewDelegate

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        switch Section(rawValue: indexPath.section) {
        case .language:
            handleLanguageSelection(at: indexPath)
        case .general:
            handleAutoUpdateToggle()
        case .storage:
            handleClearCacheTapped()
        case .repositories:
            handleResetRepositoriesTapped()
        case .system:
            handleSystemRowSelected(at: indexPath)
        case .about:
            handleAboutRowSelected(at: indexPath)
        case .none:
            break
        }
    }
    
    private func handleAutoUpdateToggle() {
        PRAppSettings.autoUpdateOnLaunch.toggle()
        tableView.reloadSections(IndexSet(integer: Section.general.rawValue), with: .automatic)
    }
    
    private func handleAboutRowSelected(at indexPath: IndexPath) {
        switch indexPath.row {
        case 0:
            navigationController?.pushViewController(PRAboutViewController(), animated: true)
        case 1:
            navigationController?.pushViewController(PRLogViewController(), animated: true)
        default:
            checkForAppUpdate()
        }
    }
    
    private func checkForAppUpdate() {
        let loadingAlert = UIAlertController(title: "SETTINGS_CHECKING_UPDATE".localized, message: nil, preferredStyle: .alert)
        present(loadingAlert, animated: true, completion: nil)
        
        Task {
            do {
                let update = try await PRAppUpdateChecker.checkForUpdate()
                
                await MainActor.run {
                    loadingAlert.dismiss(animated: true) {
                        guard let update = update else {
                            self.showSimpleAlert(title: "SETTINGS_UPDATE_NONE_TITLE".localized, message: "SETTINGS_UPDATE_NONE_MESSAGE".localized)
                            return
                        }
                        self.confirmAppUpdate(update)
                    }
                }
            } catch {
                await MainActor.run {
                    loadingAlert.dismiss(animated: true) {
                        self.showSimpleAlert(title: "COMMON_ERROR".localized, message: error.localizedDescription)
                    }
                }
            }
        }
    }
    
    private func confirmAppUpdate(_ update: PRAppUpdateInfo) {
        let alert = UIAlertController(
            title: "SETTINGS_UPDATE_AVAILABLE_TITLE".localized,
            message: String(format: "SETTINGS_UPDATE_AVAILABLE_MESSAGE".localized, update.version),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "SETTINGS_UPDATE_NOW".localized, style: .default) { [weak self] _ in
            self?.performAppUpdate(update)
        })
        alert.addAction(UIAlertAction(title: "SETTINGS_RESTART_CANCEL".localized, style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
    private func performAppUpdate(_ update: PRAppUpdateInfo) {
        let progressAlert = UIAlertController(title: "SETTINGS_UPDATE_DOWNLOADING".localized, message: nil, preferredStyle: .alert)
        present(progressAlert, animated: true, completion: nil)
        
        Task {
            do {
                let (tempURL, response) = try await URLSession.shared.download(from: update.downloadURL)
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    throw NSError(domain: "Pyra", code: -1, userInfo: [NSLocalizedDescriptionKey: "ERROR_DOWNLOAD_FAILED".localized])
                }
                
                let destination = FileManager.default.temporaryDirectory.appendingPathComponent(update.downloadURL.lastPathComponent)
                if FileManager.default.fileExists(atPath: destination.path) {
                    try FileManager.default.removeItem(at: destination)
                }
                try FileManager.default.moveItem(at: tempURL, to: destination)
                
                await MainActor.run {
                    progressAlert.dismiss(animated: true) {
                        self.installAppUpdate(from: destination)
                    }
                }
            } catch {
                await MainActor.run {
                    progressAlert.dismiss(animated: true) {
                        self.showSimpleAlert(title: "COMMON_ERROR".localized, message: error.localizedDescription)
                    }
                }
            }
        }
    }
    
    private func installAppUpdate(from fileURL: URL) {
        let installingAlert = UIAlertController(title: "SETTINGS_UPDATE_INSTALLING".localized, message: nil, preferredStyle: .alert)
        present(installingAlert, animated: true, completion: nil)
        
        Task {
            do {
                let dpkgPath = PRPathManager.shared.makePath("/usr/bin/dpkg")
                let result = try await PRSpawn.runCommand(dpkgPath, arguments: ["-i", fileURL.path], elevated: true)
                
                await MainActor.run {
                    installingAlert.dismiss(animated: true) {
                        if result.exitCode == 0 {
                            let restartAlert = UIAlertController(
                                title: "SETTINGS_UPDATE_DONE_TITLE".localized,
                                message: "SETTINGS_UPDATE_DONE_MESSAGE".localized,
                                preferredStyle: .alert
                            )
                            restartAlert.addAction(UIAlertAction(title: "SETTINGS_RESTART_CONFIRM".localized, style: .destructive) { _ in
                                // Файлы на диске уже новые, но текущий процесс всё ещё работает
                                // со старым бинарником в памяти — обязательно нужен перезапуск.
                                exit(0)
                            })
                            self.present(restartAlert, animated: true, completion: nil)
                        } else {
                            self.showSimpleAlert(title: "COMMON_ERROR".localized, message: result.stderr)
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    installingAlert.dismiss(animated: true) {
                        self.showSimpleAlert(title: "COMMON_ERROR".localized, message: error.localizedDescription)
                    }
                }
            }
        }
    }
    
    private func showSimpleAlert(title: String, message: String?) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "COMMON_OK".localized, style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
    private func handleResetRepositoriesTapped() {
        let alert = UIAlertController(
            title: "SETTINGS_RESET_REPOSITORIES_CONFIRM_TITLE".localized,
            message: "SETTINGS_RESET_REPOSITORIES_CONFIRM_MESSAGE".localized,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "SETTINGS_RESET_REPOSITORIES_CONFIRM_BUTTON".localized, style: .destructive) { [weak self] _ in
            PRRepositoryManager.shared.resetToDefault()
            self?.tableView.reloadSections(IndexSet(integer: Section.repositories.rawValue), with: .automatic)
        })
        alert.addAction(UIAlertAction(title: "SETTINGS_RESTART_CANCEL".localized, style: .cancel, handler: nil))
        
        present(alert, animated: true, completion: nil)
    }

    private func handleSystemRowSelected(at indexPath: IndexPath) {
        if indexPath.row == 0 {
            confirmRespring()
        } else {
            confirmRebuildIconCache()
        }
    }
    
    private func confirmRespring() {
        let alert = UIAlertController(
            title: "SETTINGS_RESPRING_CONFIRM_TITLE".localized,
            message: "SETTINGS_RESPRING_CONFIRM_MESSAGE".localized,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "SETTINGS_RESPRING_CONFIRM_BUTTON".localized, style: .destructive) { _ in
            self.performRespring()
        })
        alert.addAction(UIAlertAction(title: "SETTINGS_RESTART_CANCEL".localized, style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
    private func performRespring() {
        Task {
            do {
                // Сначала пробуем как обычный системный бинарник (не через бутстрап).
                // "PineBoard" — точное имя процесса домашнего экрана на tvOS, подтверждено
                // через `ps -ax` на реальном устройстве (/Applications/PineBoard.app/PineBoard).
                // Регистр важен для killall — не "Pineboard"/"SpringBoard".
                let result = try await PRSpawn.runCommand("/usr/bin/killall", arguments: ["-9", "PineBoard"], elevated: true)
                
                if result.exitCode != 0 {
                    print("Pyra: killall SpringBoard вернул код \(result.exitCode): \(result.stderr)")
                    await MainActor.run {
                        self.showSimpleAlert(
                            title: "SETTINGS_RESPRING_FAILED_TITLE".localized,
                            message: "\(result.stderr)\n\n(код: \(result.exitCode))"
                        )
                    }
                }
                // При успехе (exitCode == 0) само приложение выгрузится вместе со SpringBoard —
                // показать алерт с результатом мы просто не успеем, это ожидаемо.
            } catch {
                print("Pyra: не удалось запустить killall для respring: \(error.localizedDescription)")
                await MainActor.run {
                    self.showSimpleAlert(title: "SETTINGS_RESPRING_FAILED_TITLE".localized, message: error.localizedDescription)
                }
            }
        }
    }
    
    private func confirmRebuildIconCache() {
        let alert = UIAlertController(
            title: "SETTINGS_REBUILD_ICON_CACHE_CONFIRM_TITLE".localized,
            message: nil,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "SETTINGS_REBUILD_ICON_CACHE_CONFIRM_BUTTON".localized, style: .default) { _ in
            self.performRebuildIconCache()
        })
        alert.addAction(UIAlertAction(title: "SETTINGS_RESTART_CANCEL".localized, style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
    private func performRebuildIconCache() {
        let loadingAlert = UIAlertController(
            title: "SETTINGS_REBUILD_ICON_CACHE_RUNNING".localized,
            message: nil,
            preferredStyle: .alert
        )
        present(loadingAlert, animated: true, completion: nil)
        
        Task {
            do {
                let uicachePath = PRPathManager.shared.makePath("/usr/bin/uicache")
                let result = try await PRSpawn.runCommand(uicachePath, arguments: ["-a"], elevated: true)
                
                await MainActor.run {
                    loadingAlert.dismiss(animated: true) {
                        let resultAlert = UIAlertController(
                            title: result.exitCode == 0 ? "COMMON_SUCCESS".localized : "COMMON_ERROR".localized,
                            message: result.exitCode == 0 ? nil : result.stderr,
                            preferredStyle: .alert
                        )
                        resultAlert.addAction(UIAlertAction(title: "COMMON_OK".localized, style: .default, handler: nil))
                        self.present(resultAlert, animated: true, completion: nil)
                    }
                }
            } catch {
                await MainActor.run {
                    loadingAlert.dismiss(animated: true) {
                        let errorAlert = UIAlertController(title: "COMMON_ERROR".localized, message: error.localizedDescription, preferredStyle: .alert)
                        errorAlert.addAction(UIAlertAction(title: "COMMON_OK".localized, style: .default, handler: nil))
                        self.present(errorAlert, animated: true, completion: nil)
                    }
                }
            }
        }
    }
    
    private func handleLanguageSelection(at indexPath: IndexPath) {
        let language = languages[indexPath.row]
        guard language != PRLocalizationManager.currentLanguage else { return }

        let alert = UIAlertController(
            title: "SETTINGS_RESTART_TITLE".localized,
            message: "SETTINGS_RESTART_MESSAGE".localized,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "SETTINGS_RESTART_CONFIRM".localized, style: .destructive) { _ in
            PRLocalizationManager.currentLanguage = language
            // Очищаем лог — старые записи на предыдущем языке уже неактуальны,
            // а при следующем запуске PRLogger.start() начнёт новый чистый лог.
            PRLogger.clearLog()
            exit(0)
        })
        alert.addAction(UIAlertAction(title: "SETTINGS_RESTART_CANCEL".localized, style: .cancel, handler: nil))

        present(alert, animated: true, completion: nil)
    }

    private func handleClearCacheTapped() {
        let currentSize = PRFileManager.shared.cacheSize()
        guard currentSize > 0 else { return }

        let alert = UIAlertController(
            title: "SETTINGS_CLEAR_CACHE_CONFIRM_TITLE".localized,
            message: byteFormatter.string(fromByteCount: currentSize),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "SETTINGS_CLEAR_CACHE_CONFIRM_BUTTON".localized, style: .destructive) { [weak self] _ in
            PRFileManager.shared.clearCache()
            self?.tableView.reloadSections(IndexSet(integer: Section.storage.rawValue), with: .automatic)
        })
        alert.addAction(UIAlertAction(title: "SETTINGS_RESTART_CANCEL".localized, style: .cancel, handler: nil))

        present(alert, animated: true, completion: nil)
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        120
    }
    
    // MARK: - Яркие заголовки секций
    //
    // По умолчанию UITableView рисует заголовки секций тусклым системным серым — почти
    // не видно на тёмном фоне. Явно задаём собственный UILabel вместо стандартного текста.
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let title = sectionTitle(for: section) else { return nil }
        
        let container = UIView()
        
        let label = UILabel()
        label.text = title
        label.textColor = PRTheme.brass
        label.font = UIFont.systemFont(ofSize: 22, weight: .bold)
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)
        
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -20),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8)
        ])
        
        return container
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        guard sectionTitle(for: section) != nil else { return 0 }
        return 56
    }
    
    // tvOS сам поднимает сфокусированную строку светлой карточкой — без свапа цвета текста
    // на тёмный светлый текст на светлом фоне становится невидимым при наведении фокуса.
    func tableView(_ tableView: UITableView, didUpdateFocusIn context: UITableViewFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        if let nextIndexPath = context.nextFocusedIndexPath,
           let cell = tableView.cellForRow(at: nextIndexPath) {
            coordinator.addCoordinatedAnimations({
                self.applyTextColor(to: cell, primary: PRTheme.ink, secondary: PRTheme.ink.withAlphaComponent(0.7))
            }, completion: nil)
        }
        
        if let previousIndexPath = context.previouslyFocusedIndexPath {
            // Перерисовываем строку заново через cellForRowAt — так восстанавливается ТОЧНАЯ
            // исходная раскраска (например, латунный/серый цвет статуса "Включено"/"Выключено"),
            // а не единый жёстко заданный "цвет вне фокуса" на все строки без разбора.
            tableView.reloadRows(at: [previousIndexPath], with: .none)
        }
    }
    
    private func applyTextColor(to cell: UITableViewCell, primary: UIColor, secondary: UIColor) {
        if #available(tvOS 14.0, *), var content = cell.contentConfiguration as? UIListContentConfiguration {
            content.textProperties.color = primary
            content.secondaryTextProperties.color = secondary
            cell.contentConfiguration = content
        } else {
            cell.textLabel?.textColor = primary
            cell.detailTextLabel?.textColor = secondary
        }
    }
}
