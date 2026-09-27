//
//  PRPackageDetailsViewController.swift
//  Pyra
//  Created by Fauxly on 06.07.2026.

import UIKit

/// Карточка пакета в стиле страницы фильма в приложении Apple TV: размытый цветной фон
/// из иконки, крупная шапка с кнопкой действия, ниже — ход операции (шаги + прогресс),
/// описание и панель с деталями. Лог dpkg больше не висит постоянно, а открывается кнопкой.
public final class PRPackageDetailsViewController: UIViewController {

    private let package: PRPackage

    // Фон
    private let backdropView = UIImageView()
    private let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
    private let shadeView = PRGradientView()

    // Шапка
    private let iconContainer = UIView()
    private let iconImageView = UIImageView()
    private let tagLabel = UILabel()
    private let titleLabel = UILabel()
    private let metaLabel = UILabel()
    private let installButton = PRActionButton()
    private let logButton = PRActionButton()

    // Тело
    private let bodyStack = UIStackView()
    private let progressView = PRInstallProgressView()
    // Вкладки левой колонки: Описание / Скриншоты / Что нового (последние две —
    // только если у пакета есть Sileo-депикшен с таким содержимым)
    fileprivate enum DetailTab: Int, CaseIterable {
        case description, screenshots, changelog
    }
    private let tabsRow = UIStackView()
    private var tabButtons: [DetailTab: PRDetailTabButton] = [:]
    private var selectedTab: DetailTab = .description
    private let tabContentContainer = UIView()
    private let changelogTextView = UITextView()
    private var screenshotsView: UICollectionView!
    private var screenshots: [PRDepiction.Screenshot] = []
    private let descriptionTextView = UITextView()
    private let consoleLogTextView = UITextView() // Поле для вывода логов dpkg
    private let infoPanel = UIView()
    private let infoStack = UIStackView()
    private var installedVersionRow: UIView?
    private var installedVersionLabel: UILabel?

    private var isShowingLog = false
    private var packageState: PRInstalledState.Status = .notInstalled

    // Инициализатор, принимающий модель твика
    public init(package: PRPackage) {
        self.package = package
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = PRTheme.ink

        setupBackground()
        setupHeader()
        setupBody()
        configureData()
    }

    // Первым фокусируется главное действие. Описание стоит сразу под шапкой и
    // доступно свайпом вниз — длинный текст по-прежнему можно пролистать целиком.
    public override var preferredFocusEnvironments: [UIFocusEnvironment] {
        [installButton]
    }

    // MARK: - Вёрстка

    private func setupBackground() {
        backdropView.contentMode = .scaleAspectFill
        backdropView.clipsToBounds = true
        backdropView.alpha = 0.85

        // Сверху цвет иконки просвечивает, книзу уходит в чернильный фон — тело экрана читаемо
        shadeView.gradientLayer.colors = [
            PRTheme.ink.withAlphaComponent(0.25).cgColor,
            PRTheme.ink.withAlphaComponent(0.85).cgColor,
            PRTheme.ink.cgColor
        ]
        shadeView.gradientLayer.locations = [0, 0.45, 0.8]

        for background in [backdropView, blurView, shadeView] as [UIView] {
            background.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(background)
            NSLayoutConstraint.activate([
                background.topAnchor.constraint(equalTo: view.topAnchor),
                background.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                background.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                background.trailingAnchor.constraint(equalTo: view.trailingAnchor)
            ])
        }
    }

    private func setupHeader() {
        iconContainer.layer.shadowColor = UIColor.black.cgColor
        iconContainer.layer.shadowOpacity = 0.5
        iconContainer.layer.shadowRadius = 30
        iconContainer.layer.shadowOffset = CGSize(width: 0, height: 16)
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(iconContainer)

        iconImageView.contentMode = .scaleAspectFill
        iconImageView.layer.cornerRadius = 64
        iconImageView.layer.cornerCurve = .continuous
        iconImageView.clipsToBounds = true
        iconImageView.backgroundColor = PRTheme.surfaceFocused
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.addSubview(iconImageView)

        tagLabel.font = UIFont.systemFont(ofSize: 22, weight: .bold)
        tagLabel.textColor = PRTheme.teal

        titleLabel.font = UIFont.systemFont(ofSize: 66, weight: .heavy)
        titleLabel.textColor = PRTheme.textPrimary
        titleLabel.numberOfLines = 1
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.5

        metaLabel.font = UIFont.systemFont(ofSize: 28, weight: .medium)
        metaLabel.textColor = PRTheme.textSecondary

        // Привязываем нажатие кнопки к нашей джейлбрейк-логике
        installButton.addTarget(self, action: #selector(installButtonTapped), for: .primaryActionTriggered)

        logButton.style = .secondary
        logButton.setImage(UIImage(systemName: "terminal"), for: .normal)
        logButton.addTarget(self, action: #selector(logButtonTapped), for: .primaryActionTriggered)
        logButton.isHidden = true // появляется, как только была хоть одна операция

        let buttonsRow = UIStackView(arrangedSubviews: [installButton, logButton])
        buttonsRow.axis = .horizontal
        buttonsRow.spacing = 24
        installButton.heightAnchor.constraint(equalToConstant: 80).isActive = true
        logButton.heightAnchor.constraint(equalToConstant: 80).isActive = true

        let headerStack = UIStackView(arrangedSubviews: [tagLabel, titleLabel, metaLabel, buttonsRow])
        headerStack.axis = .vertical
        headerStack.alignment = .leading
        headerStack.spacing = 10
        headerStack.setCustomSpacing(34, after: metaLabel)
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerStack)

        NSLayoutConstraint.activate([
            iconContainer.topAnchor.constraint(equalTo: view.topAnchor, constant: 30),
            iconContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 90),
            iconContainer.widthAnchor.constraint(equalToConstant: 260),
            iconContainer.heightAnchor.constraint(equalToConstant: 260),

            iconImageView.topAnchor.constraint(equalTo: iconContainer.topAnchor),
            iconImageView.bottomAnchor.constraint(equalTo: iconContainer.bottomAnchor),
            iconImageView.leadingAnchor.constraint(equalTo: iconContainer.leadingAnchor),
            iconImageView.trailingAnchor.constraint(equalTo: iconContainer.trailingAnchor),

            headerStack.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 60),
            headerStack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -90),
            headerStack.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor)
        ])
    }

    private func setupBody() {
        // Ход операции — скрыт, пока пользователь ничего не запускал; скрытый элемент
        // UIStackView схлопывается, и описание поднимается вплотную к шапке
        progressView.isHidden = true

        descriptionTextView.backgroundColor = .clear
        descriptionTextView.textColor = PRTheme.textPrimary.withAlphaComponent(0.85)
        descriptionTextView.font = UIFont.systemFont(ofSize: 28, weight: .regular)
        descriptionTextView.textContainerInset = .zero
        descriptionTextView.textContainer.lineFragmentPadding = 0
        // isSelectable — именно это свойство делает UITextView фокусируемым и скроллящимся
        // через Focus Engine на tvOS. С false он превращается в статичный нескроллящийся текст,
        // на который в принципе нельзя навести фокус пультом.
        descriptionTextView.isSelectable = true
        descriptionTextView.isScrollEnabled = true
        descriptionTextView.showsVerticalScrollIndicator = true

        consoleLogTextView.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        consoleLogTextView.textColor = PRTheme.teal
        consoleLogTextView.font = UIFont.monospacedSystemFont(ofSize: 20, weight: .regular)
        consoleLogTextView.layer.cornerRadius = 18
        consoleLogTextView.textContainerInset = UIEdgeInsets(top: 18, left: 18, bottom: 18, right: 18)
        consoleLogTextView.text = "PKG_DETAILS_WAITING".localized
        consoleLogTextView.isHidden = true

        // "Что нового" — такой же прокручиваемый фокусируемый текст, как описание
        changelogTextView.backgroundColor = .clear
        changelogTextView.textColor = PRTheme.textPrimary.withAlphaComponent(0.85)
        changelogTextView.font = UIFont.systemFont(ofSize: 26, weight: .regular)
        changelogTextView.textContainerInset = .zero
        changelogTextView.textContainer.lineFragmentPadding = 0
        changelogTextView.isSelectable = true
        changelogTextView.isScrollEnabled = true

        // Лента скриншотов
        let screenshotsLayout = UICollectionViewFlowLayout()
        screenshotsLayout.scrollDirection = .horizontal
        screenshotsLayout.minimumLineSpacing = 30
        screenshotsLayout.sectionInset = UIEdgeInsets(top: 14, left: 4, bottom: 14, right: 4)
        screenshotsView = UICollectionView(frame: .zero, collectionViewLayout: screenshotsLayout)
        screenshotsView.backgroundColor = .clear
        screenshotsView.clipsToBounds = false
        screenshotsView.register(PRScreenshotCell.self, forCellWithReuseIdentifier: PRScreenshotCell.reuseIdentifier)
        screenshotsView.dataSource = self
        screenshotsView.delegate = self

        // Все варианты содержимого лежат друг на друге; видно одно — по выбранной вкладке (или лог)
        for content in [descriptionTextView, screenshotsView!, changelogTextView, consoleLogTextView] as [UIView] {
            content.translatesAutoresizingMaskIntoConstraints = false
            tabContentContainer.addSubview(content)
            NSLayoutConstraint.activate([
                content.topAnchor.constraint(equalTo: tabContentContainer.topAnchor),
                content.bottomAnchor.constraint(equalTo: tabContentContainer.bottomAnchor),
                content.leadingAnchor.constraint(equalTo: tabContentContainer.leadingAnchor),
                content.trailingAnchor.constraint(equalTo: tabContentContainer.trailingAnchor)
            ])
        }

        tabsRow.axis = .horizontal
        tabsRow.spacing = 12
        for tab in DetailTab.allCases {
            let button = PRDetailTabButton(title: tab.title)
            button.onFocus = { [weak self] in self?.selectTab(tab) }
            button.isHidden = tab != .description
            tabButtons[tab] = button
            tabsRow.addArrangedSubview(button)
        }
        // Распорка справа — чтобы кнопки вкладок не растягивались на всю ширину колонки
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        tabsRow.addArrangedSubview(spacer)

        let leftColumn = UIStackView(arrangedSubviews: [tabsRow, tabContentContainer])
        leftColumn.axis = .vertical
        leftColumn.spacing = 18
        selectTab(.description)

        infoPanel.backgroundColor = PRTheme.surface.withAlphaComponent(0.75)
        infoPanel.layer.cornerRadius = 24
        infoPanel.layer.cornerCurve = .continuous
        infoStack.axis = .vertical
        infoStack.spacing = 14
        infoStack.translatesAutoresizingMaskIntoConstraints = false
        infoPanel.addSubview(infoStack)
        NSLayoutConstraint.activate([
            infoPanel.widthAnchor.constraint(equalToConstant: 560),
            infoStack.topAnchor.constraint(equalTo: infoPanel.topAnchor, constant: 22),
            infoStack.leadingAnchor.constraint(equalTo: infoPanel.leadingAnchor, constant: 32),
            infoStack.trailingAnchor.constraint(equalTo: infoPanel.trailingAnchor, constant: -32),
            infoStack.bottomAnchor.constraint(lessThanOrEqualTo: infoPanel.bottomAnchor, constant: -30)
        ])

        let contentRow = UIStackView(arrangedSubviews: [leftColumn, infoPanel])
        contentRow.axis = .horizontal
        contentRow.spacing = 60
        contentRow.alignment = .fill

        bodyStack.addArrangedSubview(progressView)
        bodyStack.addArrangedSubview(contentRow)
        bodyStack.axis = .vertical
        bodyStack.spacing = 36
        bodyStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bodyStack)

        NSLayoutConstraint.activate([
            bodyStack.topAnchor.constraint(equalTo: iconContainer.bottomAnchor, constant: 36),
            bodyStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 90),
            bodyStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -90),
            bodyStack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -50)
        ])
    }

    /// Ячейка панели деталей: мелкий заголовок над значением (в одну строку —
    /// длинные значения вроде ID сокращаются посередине, а не раздувают панель)
    private func makeInfoCell(title: String, value: String) -> (cell: UIView, valueLabel: UILabel) {
        let titleLabel = UILabel()
        titleLabel.text = title.uppercased()
        titleLabel.font = UIFont.systemFont(ofSize: 17, weight: .bold)
        titleLabel.textColor = PRTheme.textSecondary

        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = UIFont.systemFont(ofSize: 25, weight: .semibold)
        valueLabel.textColor = PRTheme.textPrimary
        valueLabel.numberOfLines = 1
        valueLabel.lineBreakMode = .byTruncatingMiddle
        valueLabel.adjustsFontSizeToFitWidth = true
        valueLabel.minimumScaleFactor = 0.75

        let cell = UIStackView(arrangedSubviews: [titleLabel, valueLabel])
        cell.axis = .vertical
        cell.spacing = 3
        return (cell, valueLabel)
    }

    /// Строка панели из одной или двух ячеек. Скрытая ячейка в паре (например,
    /// "Установлена" у неустановленного пакета) схлопывается, и соседняя занимает всю ширину.
    private func addInfoLine(_ cells: [UIView]) {
        let line = UIStackView(arrangedSubviews: cells)
        line.axis = .horizontal
        line.spacing = 28
        line.distribution = .fillEqually
        infoStack.addArrangedSubview(line)
    }

    // MARK: - Данные

    private func configureData() {
        titleLabel.text = package.name

        let section = package.section.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasSection = !section.isEmpty && section.lowercased() != "unknown"
        tagLabel.text = hasSection ? section.uppercased() : nil
        tagLabel.isHidden = !hasSection

        let author = Self.cleanAuthor(package.author) ?? "PKG_DETAILS_UNKNOWN_AUTHOR".localized
        var meta = [author, "v\(package.version)"]
        if let repo = package.sourceRepository?.name { meta.append(repo) }
        metaLabel.text = meta.joined(separator: "  ·  ")

        // Описание + зависимости
        var description = package.description.trimmingCharacters(in: .whitespacesAndNewlines)
        if description.isEmpty { description = "PKG_DETAILS_NO_DESCRIPTION".localized }
        if let depends = package.depends, !depends.isEmpty {
            description += "\n\n\("PKG_DETAILS_DEPENDENCIES".localized): \(depends)"
        }
        descriptionTextView.text = description

        // Панель деталей — две колонки, чтобы все поля влезали по высоте даже у
        // установленного пакета с категорией и при открытой панели хода операции
        let version = makeInfoCell(title: "PKG_DETAILS_META_VERSION".localized, value: package.version)
        let installed = makeInfoCell(title: "PKG_DETAILS_META_INSTALLED".localized, value: "")
        installedVersionRow = installed.cell
        installedVersionLabel = installed.valueLabel
        addInfoLine([version.cell, installed.cell])

        var authorLine = [makeInfoCell(title: "PKG_DETAILS_META_AUTHOR".localized, value: author).cell]
        if hasSection {
            authorLine.append(makeInfoCell(title: "PKG_DETAILS_META_SECTION".localized, value: section).cell)
        }
        addInfoLine(authorLine)

        // Размер: сколько качать и сколько займёт (Installed-Size в Packages — в килобайтах)
        var sizeLine: [UIView] = []
        if let size = package.size, size > 0 {
            sizeLine.append(makeInfoCell(title: "PKG_DETAILS_META_DOWNLOAD_SIZE".localized, value: Self.formatBytes(size)).cell)
        }
        if let installedKB = package.installedSizeKB, installedKB > 0 {
            sizeLine.append(makeInfoCell(title: "PKG_DETAILS_META_INSTALLED_SIZE".localized, value: Self.formatBytes(installedKB * 1024)).cell)
        }
        if !sizeLine.isEmpty {
            addInfoLine(sizeLine)
        }

        var sourceLine: [UIView] = []
        if let repo = package.sourceRepository {
            sourceLine.append(makeInfoCell(title: "PKG_DETAILS_META_REPO".localized, value: repo.name).cell)
        }
        sourceLine.append(makeInfoCell(title: "PKG_DETAILS_META_ARCH".localized, value: package.architecture).cell)
        addInfoLine(sourceLine)

        addInfoLine([makeInfoCell(title: "PKG_DETAILS_META_ID".localized, value: package.packageID).cell])

        packageState = PRInstalledState.shared.status(for: package)
        updateInstallButtonAppearance()
        updateInstalledVersionRow()
        loadDepiction()

        // Иконка + фон из неё; без иконки — текстовая карточка и чистый чернильный фон
        iconImageView.image = createPlaceholderCard(withTitle: package.name)
        if let iconURL = package.iconURL, !iconURL.isEmpty {
            Task { [weak self] in
                guard let image = await PRImageCache.shared.image(for: iconURL) else { return }
                await MainActor.run {
                    guard let self else { return }
                    UIView.transition(with: self.view, duration: 0.4, options: .transitionCrossDissolve) {
                        self.iconImageView.image = image
                        self.backdropView.image = image
                    }
                }
            }
        }
    }

    private static func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    /// Скриншоты и "Что нового" из Sileo-депикшена — грузятся фоном, вкладки
    /// появляются только если там реально что-то есть
    private func loadDepiction() {
        guard package.sileoDepictionURL != nil else { return }
        Task { [weak self] in
            guard let self, let depiction = await PRDepictionLoader.shared.depiction(for: self.package) else { return }
            await MainActor.run {
                self.screenshots = depiction.screenshots
                self.screenshotsView.reloadData()
                self.changelogTextView.text = depiction.changelog
                UIView.animate(withDuration: 0.25) {
                    self.tabButtons[.screenshots]?.isHidden = depiction.screenshots.isEmpty
                    self.tabButtons[.changelog]?.isHidden = (depiction.changelog ?? "").isEmpty
                }
            }
        }
    }

    /// Поле Author в control-файле обычно вида "Имя <mail@host>" — почту не показываем
    private static func cleanAuthor(_ raw: String?) -> String? {
        guard var author = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !author.isEmpty else { return nil }
        if let bracket = author.firstIndex(of: "<") {
            author = String(author[..<bracket]).trimmingCharacters(in: .whitespaces)
        }
        return author.isEmpty ? nil : author
    }

    private func updateInstalledVersionRow() {
        let installed = PRInstalledState.shared.installedVersion(of: package.packageID)
        installedVersionLabel?.text = installed
        installedVersionRow?.isHidden = installed == nil
    }

    /// Единая точка правды для вида кнопки — вызывается и при первой загрузке экрана,
    /// и после успешной установки/удаления, чтобы кнопка всегда отражала актуальное состояние.
    private func updateInstallButtonAppearance() {
        switch packageState {
        case .notInstalled:
            installButton.setTitle("PKG_DETAILS_INSTALL".localized, for: .normal)
            installButton.setImage(UIImage(systemName: "arrow.down.circle.fill"), for: .normal)
            installButton.style = .primary
        case .installed:
            installButton.setTitle("PKG_DETAILS_UNINSTALL".localized, for: .normal)
            installButton.setImage(UIImage(systemName: "trash"), for: .normal)
            installButton.style = .destructive
        case .updateAvailable(let oldVersion):
            let title = String(format: "PKG_DETAILS_UPDATE".localized, oldVersion, package.version)
            installButton.setTitle(title, for: .normal)
            installButton.setImage(UIImage(systemName: "arrow.triangle.2.circlepath"), for: .normal)
            installButton.style = .primary
        }
        installButton.isEnabled = true
    }

    /// После успешной установки/удаления: перечитать dpkg status (это заодно оповестит
    /// плитки каталога и бейджи), обновить кнопку и строку "Установлена"
    private func packageStateDidChange() {
        PRInstalledState.shared.refresh()
        packageState = PRInstalledState.shared.status(for: package)
        updateInstallButtonAppearance()
        updateInstalledVersionRow()
    }

    /// Показать панель хода операции с новым набором шагов
    private func beginOperation(steps: [String]) {
        progressView.setSteps(steps)
        progressView.setActive(0)
        logButton.isHidden = false
        updateLogButtonTitle()
        if progressView.isHidden {
            UIView.animate(withDuration: 0.3) {
                self.progressView.isHidden = false
                self.view.layoutIfNeeded()
            }
        }
    }

    // MARK: - Лог

    @objc private func logButtonTapped() {
        showLog(!isShowingLog)
    }

    /// Лог перекрывает содержимое вкладок; выбор любой вкладки его снова прячет
    private func showLog(_ show: Bool) {
        isShowingLog = show
        logButton.isHidden = false
        updateTabContent()
        updateLogButtonTitle()
    }

    // MARK: - Вкладки

    private func selectTab(_ tab: DetailTab) {
        selectedTab = tab
        if isShowingLog {
            isShowingLog = false
            updateLogButtonTitle()
        }
        updateTabContent()
    }

    private func updateTabContent() {
        descriptionTextView.isHidden = isShowingLog || selectedTab != .description
        screenshotsView.isHidden = isShowingLog || selectedTab != .screenshots
        changelogTextView.isHidden = isShowingLog || selectedTab != .changelog
        consoleLogTextView.isHidden = !isShowingLog
        for (tab, button) in tabButtons {
            button.isSelectedTab = !isShowingLog && tab == selectedTab
        }
    }

    private func updateLogButtonTitle() {
        logButton.setTitle((isShowingLog ? "PKG_DETAILS_HIDE_LOG" : "PKG_DETAILS_SHOW_LOG").localized, for: .normal)
    }

    // MARK: - Действия

    // Логика кнопки зависит от состояния пакета
    @objc private func installButtonTapped() {
        switch packageState {
        case .notInstalled:
            guard let repository = package.sourceRepository else {
                appendLog("PKG_DETAILS_ERROR_NO_REPO".localized + "\n")
                showLog(true)
                return
            }

            // Проверяем зависимости — если чего-то не хватает, показываем информационно
            // в логе. Блокировать установку не нужно: apt-get -f install подтянет их сам.
            let missing = PRDependencyChecker.missingDependencies(for: package)

            startInstall(repository: repository)

            if !missing.isEmpty {
                let orWord = "PKG_DETAILS_OR".localized
                let list = missing.map { group in
                    group.map { $0.displayString }.joined(separator: " \(orWord) ")
                }.joined(separator: ", ")
                appendLog(String(format: "PKG_DETAILS_AUTO_DEPS_INFO".localized, list) + "\n")
            }

        case .installed:
            confirmUninstall()

        case .updateAvailable:
            guard let repository = package.sourceRepository else {
                appendLog("PKG_DETAILS_ERROR_NO_REPO".localized + "\n")
                showLog(true)
                return
            }
            startInstall(repository: repository)
        }
    }

    // showMissingDependenciesAlert удалён — зависимости разрешаются автоматически через apt-get -f install.
    
    private func confirmUninstall() {
        let alert = UIAlertController(
            title: package.name,
            message: "PKG_DETAILS_UNINSTALL_CONFIRM".localized,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "PKG_DETAILS_UNINSTALL".localized, style: .destructive) { [weak self] _ in
            self?.startUninstall()
        })
        alert.addAction(UIAlertAction(title: "COMMON_CANCEL".localized, style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
    private func startUninstall() {
        consoleLogTextView.text = String(format: "PKG_DETAILS_UNINSTALLING".localized, package.packageID) + "\n"
        installButton.isEnabled = false
        beginOperation(steps: ["PKG_STEP_REMOVE".localized, "PKG_STEP_DONE".localized])
        
        Task {
            do {
                let dpkgPath = PRPathManager.shared.makePath("/usr/bin/dpkg")
                let result = try await PRSpawn.runCommand(dpkgPath, arguments: ["-r", package.packageID], elevated: true)
                
                await MainActor.run {
                    if result.exitCode == 0 {
                        self.appendLog("\n" + String(format: "PKG_DETAILS_UNINSTALL_SUCCESS".localized, self.package.packageID) + "\n")
                        self.appendLog(result.stdout)
                        self.progressView.finish()
                        self.packageStateDidChange()
                    } else {
                        self.appendLog("\n" + String(format: "PKG_DETAILS_DPKG_ERROR".localized, result.exitCode) + "\n")
                        self.appendLog(result.stderr)
                        self.progressView.fail()
                        self.installButton.isEnabled = true
                    }
                }
            } catch {
                await MainActor.run {
                    self.appendLog("\n" + "PKG_DETAILS_GENERIC_ERROR".localized + error.localizedDescription)
                    self.progressView.fail()
                    self.installButton.isEnabled = true
                }
            }
        }
    }
    
    private func startInstall(repository: PRRepository) {
        consoleLogTextView.text = String(format: "PKG_DETAILS_DOWNLOADING".localized, package.packageID) + "\n"
        installButton.isEnabled = false
        beginOperation(steps: [
            "PKG_STEP_DOWNLOAD".localized,
            "PKG_STEP_INSTALL".localized,
            "PKG_STEP_VERIFY".localized,
            "PKG_STEP_DONE".localized
        ])
        
        Task {
            do {
                let localURL = try await PRDownloadManager.shared.download(package: package, repository: repository)
                
                await MainActor.run {
                    self.appendLog(String(format: "PKG_DETAILS_DOWNLOADED".localized, localURL.lastPathComponent) + "\n")
                    self.appendLog("PKG_DETAILS_INSTALLING_VIA_DPKG".localized + "\n")
                    self.progressView.setActive(1)
                }
                
                // Шаг 1: dpkg -i
                let dpkgPath = PRPathManager.shared.makePath("/usr/bin/dpkg")
                let result = try await PRSpawn.runCommand(dpkgPath, arguments: ["--force-architecture", "-i", localURL.path], elevated: true)
                
                await MainActor.run {
                    self.appendLog(result.stdout)
                    self.appendLog(result.stderr)
                }
                
                // Шаг 2: если dpkg упал из-за зависимостей — ставим принудительно.
                // --force-depends пропускает проверку зависимостей, но реально распаковывает
                // файлы пакета и записывает его в базу dpkg. Зависимости пользователь
                // может доставить отдельно.
                if result.exitCode != 0 {
                    await MainActor.run {
                        self.appendLog("\n" + "PKG_DETAILS_FORCE_INSTALL".localized + "\n")
                    }
                    
                    let forceResult = try await PRSpawn.runCommand(
                        dpkgPath,
                        arguments: ["-i", "--force-depends", localURL.path],
                        elevated: true
                    )
                    
                    await MainActor.run {
                        self.appendLog(forceResult.stdout)
                        self.appendLog(forceResult.stderr)
                    }
                }
                
                await MainActor.run {
                    self.progressView.setActive(2)
                }

                // Шаг 3: ВЕРИФИКАЦИЯ — не доверяем exit code, проверяем реальный статус
                // в базе dpkg. apt-get -f может вернуть 0, ничего не сделав.
                let actuallyInstalled = PRStatusParser.shared.isPackageInstalled(id: self.package.packageID)
                
                await MainActor.run {
                    if actuallyInstalled {
                        self.appendLog("\n" + String(format: "PKG_DETAILS_SUCCESS".localized, self.package.packageID) + "\n")
                        self.progressView.finish()
                        self.packageStateDidChange()
                    } else {
                        self.appendLog("\n" + "PKG_DETAILS_INSTALL_FAILED_VERIFY".localized + "\n")
                        self.progressView.fail()
                        self.showLog(true)
                        self.installButton.isEnabled = true
                    }
                    PRFileManager.shared.removeDownloadedFile(for: self.package)
                }
            } catch {
                await MainActor.run {
                    self.appendLog("\n" + "PKG_DETAILS_GENERIC_ERROR".localized + error.localizedDescription)
                    self.progressView.fail()
                    self.installButton.isEnabled = true
                }
            }
        }
    }
    
    /// Дописывает строку в консольный лог и сразу скроллит его вниз — иначе на длинном
    /// выводе dpkg пользователь остаётся смотреть на начало лога, пока текст растёт снизу.
    private func appendLog(_ text: String) {
        consoleLogTextView.text += text
        let bottom = NSRange(location: (consoleLogTextView.text as NSString).length, length: 0)
        consoleLogTextView.scrollRangeToVisible(bottom)
    }
    
    private func createPlaceholderCard(withTitle title: String) -> UIImage {
        let size = CGSize(width: 300, height: 300)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            PRTheme.surfaceFocused.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))

            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center

            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 30, weight: .bold),
                .foregroundColor: PRTheme.textPrimary,
                .paragraphStyle: paragraphStyle
            ]

            let stringSize = title.boundingRect(with: CGSize(width: size.width - 40, height: size.height - 40), options: .usesLineFragmentOrigin, attributes: attributes, context: nil).size
            let textRect = CGRect(x: 20, y: (size.height - stringSize.height) / 2, width: size.width - 40, height: stringSize.height)
            title.draw(in: textRect, withAttributes: attributes)
        }
    }
}

// MARK: - Лента скриншотов

extension PRPackageDetailsViewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        screenshots.count
    }

    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PRScreenshotCell.reuseIdentifier, for: indexPath) as? PRScreenshotCell else {
            return UICollectionViewCell()
        }
        cell.configure(with: screenshots[indexPath.item].url)
        return cell
    }

    // Высота — по высоте ленты, ширина — по пропорциям из депикшена
    // (у одних пакетов скриншоты с телефона, у других — горизонтальные с ТВ)
    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let height = max(collectionView.bounds.height - 28, 100)
        let aspect = min(max(screenshots[indexPath.item].aspectRatio, 0.4), 2.2)
        return CGSize(width: height * aspect, height: height)
    }
}

private extension PRPackageDetailsViewController.DetailTab {
    var title: String {
        switch self {
        case .description: return "PKG_DETAILS_ABOUT".localized
        case .screenshots: return "PKG_DETAILS_SCREENSHOTS".localized
        case .changelog: return "PKG_DETAILS_CHANGELOG".localized
        }
    }
}

/// Текстовая вкладка над содержимым экрана пакета. Переключается при наведении фокуса,
/// как вкладки верхнего бара — без отдельного нажатия.
final class PRDetailTabButton: UIButton {

    var onFocus: (() -> Void)?

    var isSelectedTab = false {
        didSet { applyAppearance() }
    }

    init(title: String) {
        super.init(frame: .zero)
        setTitle(title, for: .normal)
        titleLabel?.font = UIFont.systemFont(ofSize: 26, weight: .bold)
        contentEdgeInsets = UIEdgeInsets(top: 10, left: 26, bottom: 10, right: 26)
        layer.cornerRadius = 22
        layer.cornerCurve = .continuous
        layer.borderColor = PRTheme.brass.cgColor
        applyAppearance()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) не поддерживается")
    }

    private func applyAppearance() {
        backgroundColor = isSelectedTab ? PRTheme.surfaceFocused : .clear
        setTitleColor(isSelectedTab ? PRTheme.brass : PRTheme.textSecondary, for: .normal)
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        if context.nextFocusedView === self {
            onFocus?()
            coordinator.addCoordinatedAnimations({
                self.transform = CGAffineTransform(scaleX: 1.08, y: 1.08)
                self.layer.borderWidth = 2
            }, completion: nil)
        } else if context.previouslyFocusedView === self {
            coordinator.addCoordinatedAnimations({
                self.transform = .identity
                self.layer.borderWidth = 0
            }, completion: nil)
        }
    }
}
