//
//  PRSettingsViewController.swift
//  Pyra
//  Created by Fauxly on 06.07.2026.

import UIKit

/// Настройки — сверху карточка Pyra (версия, окружение, проверка обновлений), ниже
/// плитки настроек по группам с цветными иконками. Переключатели показаны "таблеткой",
/// действия с последствиями (respring, сброс, очистка) по-прежнему спрашивают подтверждение.
final class PRSettingsViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {

    private struct Tile {
        let symbol: String
        let color: UIColor
        let title: String
        var value: String? = nil
        var highlightValue = false
        var toggle: Bool? = nil
        let action: () -> Void
    }

    private struct TileSection {
        let title: String
        let tiles: [Tile]
    }

    private enum Palette {
        static let blue = UIColor(red: 0x7F / 255, green: 0xB0 / 255, blue: 0xE8 / 255, alpha: 1)
        static let lavender = UIColor(red: 0x9D / 255, green: 0x8F / 255, blue: 0xE0 / 255, alpha: 1)
        static let coral = UIColor(red: 0xE0 / 255, green: 0x8A / 255, blue: 0x7A / 255, alpha: 1)
        static let olive = UIColor(red: 0x9C / 255, green: 0xC4 / 255, blue: 0x6E / 255, alpha: 1)
    }

    private var collectionView: UICollectionView!
    private var sections: [TileSection] = []
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

        let header = makeHeaderCard()
        view.addSubview(header)

        let layout = UICollectionViewCompositionalLayout { _, _ in
            PRGridLayout.section(columns: 2, itemHeight: 140, spacing: 36, header: true, topInset: 6, bottomInset: 30)
        }
        collectionView = PRGridLayout.makeCollectionView(in: view, layout: layout)
        collectionView.register(PRSettingTileCell.self, forCellWithReuseIdentifier: PRSettingTileCell.reuseIdentifier)
        collectionView.register(PRSectionHeaderView.self,
                                forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
                                withReuseIdentifier: PRSectionHeaderView.reuseIdentifier)
        collectionView.dataSource = self
        collectionView.delegate = self

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.topAnchor, constant: 24),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: PRGridLayout.horizontalInset),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -PRGridLayout.horizontalInset),
            header.heightAnchor.constraint(equalToConstant: 170),

            collectionView.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 10),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Размер кэша и число источников могли поменяться на других вкладках
        collectionView.reloadData()
    }

    // MARK: - Карточка Pyra

    private func makeHeaderCard() -> UIView {
        let card = UIView()
        card.backgroundColor = PRTheme.surface
        card.layer.cornerRadius = 30
        card.layer.cornerCurve = .continuous
        card.translatesAutoresizingMaskIntoConstraints = false

        let glow = PRGradientView()
        glow.gradientLayer.colors = [PRTheme.brass.withAlphaComponent(0.25).cgColor, PRTheme.brass.withAlphaComponent(0).cgColor]
        glow.gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        glow.gradientLayer.endPoint = CGPoint(x: 0.7, y: 0.5)
        glow.layer.cornerRadius = 30
        glow.clipsToBounds = true
        glow.isUserInteractionEnabled = false
        glow.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(glow)

        // Pyra — "огонь": латунное пламя в скруглённом квадрате как знак приложения
        let logo = UIView()
        logo.backgroundColor = PRTheme.brass
        logo.layer.cornerRadius = 30
        logo.layer.cornerCurve = .continuous
        logo.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(logo)
        let flame = UIImageView(image: UIImage(systemName: "flame.fill"))
        flame.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 54, weight: .bold)
        flame.tintColor = PRTheme.ink
        flame.translatesAutoresizingMaskIntoConstraints = false
        logo.addSubview(flame)

        let nameLabel = UILabel()
        nameLabel.text = "Pyra"
        nameLabel.font = UIFont.systemFont(ofSize: 52, weight: .heavy)
        nameLabel.textColor = PRTheme.textPrimary

        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        let environment = PRPathManager.shared.isRootless ? "Rootless" : "Rootful"
        let metaLabel = UILabel()
        metaLabel.text = "v\(version) (\(build))  ·  \(environment)  ·  tvOS \(UIDevice.current.systemVersion)"
        metaLabel.font = UIFont.systemFont(ofSize: 24, weight: .medium)
        metaLabel.textColor = PRTheme.textSecondary

        let textStack = UIStackView(arrangedSubviews: [nameLabel, metaLabel])
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(textStack)

        let updateButton = PRActionButton()
        updateButton.setImage(UIImage(systemName: "arrow.down.circle.fill"), for: .normal)
        updateButton.setTitle("SETTINGS_CHECK_UPDATE".localized, for: .normal)
        updateButton.addTarget(self, action: #selector(checkUpdateTapped), for: .primaryActionTriggered)
        updateButton.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(updateButton)

        NSLayoutConstraint.activate([
            glow.topAnchor.constraint(equalTo: card.topAnchor),
            glow.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            glow.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            glow.trailingAnchor.constraint(equalTo: card.trailingAnchor),

            logo.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 36),
            logo.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            logo.widthAnchor.constraint(equalToConstant: 110),
            logo.heightAnchor.constraint(equalToConstant: 110),
            flame.centerXAnchor.constraint(equalTo: logo.centerXAnchor),
            flame.centerYAnchor.constraint(equalTo: logo.centerYAnchor),

            textStack.leadingAnchor.constraint(equalTo: logo.trailingAnchor, constant: 32),
            textStack.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: updateButton.leadingAnchor, constant: -30),

            updateButton.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -40),
            updateButton.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            updateButton.heightAnchor.constraint(equalToConstant: 80)
        ])
        return card
    }

    @objc private func checkUpdateTapped() {
        checkForAppUpdate()
    }

    // MARK: - Плитки

    /// Собирается заново при каждой перерисовке — значения (кэш, число источников,
    /// состояние переключателя) всегда актуальные
    private func makeSections() -> [TileSection] {
        // Собираем по шагам с явными типами, а не одним большим литералом массива —
        // иначе компилятор (особенно с -O в Release) может не успеть вывести типы
        let autoUpdate: Bool = PRAppSettings.autoUpdateOnLaunch
        let autoUpdateText: String = autoUpdate ? "SETTINGS_STATE_ON".localized : "SETTINGS_STATE_OFF".localized
        let cacheText: String = byteFormatter.string(fromByteCount: PRFileManager.shared.cacheSize())
        let sourcesText: String = String(format: "SETTINGS_REPOSITORIES_COUNT".localized, PRRepositoryManager.shared.repositories.count)

        let language = Tile(symbol: "globe", color: Palette.blue,
                            title: "SETTINGS_LANGUAGE_SECTION".localized,
                            value: PRLocalizationManager.currentLanguage.displayName,
                            action: { [weak self] in self?.showLanguagePicker() })
        let autoUpdateTile = Tile(symbol: "arrow.clockwise.circle.fill", color: PRTheme.teal,
                                  title: "SETTINGS_AUTO_UPDATE".localized,
                                  value: autoUpdateText,
                                  highlightValue: autoUpdate,
                                  toggle: autoUpdate,
                                  action: { [weak self] in self?.handleAutoUpdateToggle() })

        let clearCache = Tile(symbol: "externaldrive.fill", color: Palette.lavender,
                              title: "SETTINGS_CLEAR_CACHE".localized,
                              value: cacheText,
                              action: { [weak self] in self?.handleClearCacheTapped() })
        let resetSources = Tile(symbol: "tray.2.fill", color: PRTheme.brass,
                                title: "SETTINGS_RESET_REPOSITORIES".localized,
                                value: sourcesText,
                                action: { [weak self] in self?.handleResetRepositoriesTapped() })

        let respring = Tile(symbol: "arrow.counterclockwise.circle.fill", color: Palette.coral,
                            title: "SETTINGS_RESPRING".localized,
                            value: "SETTINGS_RESPRING_HINT".localized,
                            action: { [weak self] in self?.confirmRespring() })
        let iconCache = Tile(symbol: "square.grid.3x3.fill", color: Palette.olive,
                             title: "SETTINGS_REBUILD_ICON_CACHE".localized,
                             value: "uicache -a",
                             action: { [weak self] in self?.confirmRebuildIconCache() })

        let about = Tile(symbol: "info.circle.fill", color: Palette.blue,
                         title: "SETTINGS_ABOUT".localized,
                         action: { [weak self] in self?.openAbout() })
        let log = Tile(symbol: "doc.text.magnifyingglass", color: Palette.lavender,
                       title: "SETTINGS_DIAGNOSTIC_LOG".localized,
                       action: { [weak self] in self?.openLog() })

        var result: [TileSection] = []
        result.append(TileSection(title: "SETTINGS_GENERAL_SECTION".localized, tiles: [language, autoUpdateTile]))
        result.append(TileSection(title: "SETTINGS_STORAGE_SECTION".localized, tiles: [clearCache, resetSources]))
        result.append(TileSection(title: "SETTINGS_SYSTEM_SECTION".localized, tiles: [respring, iconCache]))
        result.append(TileSection(title: "SETTINGS_ABOUT_SECTION".localized, tiles: [about, log]))
        return result
    }

    private func openAbout() {
        navigationController?.pushViewController(PRAboutViewController(), animated: true)
    }

    private func openLog() {
        navigationController?.pushViewController(PRLogViewController(), animated: true)
    }

    // MARK: - UICollectionViewDataSource

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        sections = makeSections()
        return sections.count
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        sections[section].tiles.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PRSettingTileCell.reuseIdentifier, for: indexPath) as? PRSettingTileCell else {
            return UICollectionViewCell()
        }
        let tile = sections[indexPath.section].tiles[indexPath.item]
        cell.configure(symbol: tile.symbol, color: tile.color, title: tile.title,
                       value: tile.value, highlightValue: tile.highlightValue, toggle: tile.toggle)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        guard let header = collectionView.dequeueReusableSupplementaryView(
            ofKind: kind, withReuseIdentifier: PRSectionHeaderView.reuseIdentifier, for: indexPath
        ) as? PRSectionHeaderView else {
            return UICollectionReusableView()
        }
        header.leadingInset = PRGridLayout.horizontalInset
        header.configure(title: sections[indexPath.section].title)
        return header
    }

    // MARK: - UICollectionViewDelegate

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        sections[indexPath.section].tiles[indexPath.item].action()
    }

    // MARK: - Действия

    private func handleAutoUpdateToggle() {
        PRAppSettings.autoUpdateOnLaunch.toggle()
        collectionView.reloadData()
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
            self?.collectionView.reloadData()
        })
        alert.addAction(UIAlertAction(title: "SETTINGS_RESTART_CANCEL".localized, style: .cancel, handler: nil))
        
        present(alert, animated: true, completion: nil)
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
    
    /// Выбор языка — список языков, текущий отмечен галочкой
    private func showLanguagePicker() {
        let picker = UIAlertController(title: "SETTINGS_LANGUAGE_SECTION".localized, message: nil, preferredStyle: .alert)
        for language in languages {
            let isCurrent = language == PRLocalizationManager.currentLanguage
            picker.addAction(UIAlertAction(title: (isCurrent ? "✓ " : "") + language.displayName, style: .default) { [weak self] _ in
                self?.selectLanguage(language)
            })
        }
        picker.addAction(UIAlertAction(title: "SETTINGS_RESTART_CANCEL".localized, style: .cancel, handler: nil))
        present(picker, animated: true, completion: nil)
    }

    private func selectLanguage(_ language: PRLanguage) {
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
            self?.collectionView.reloadData()
        })
        alert.addAction(UIAlertAction(title: "SETTINGS_RESTART_CANCEL".localized, style: .cancel, handler: nil))

        present(alert, animated: true, completion: nil)
    }

}
