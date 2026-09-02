//
//  PRPackageDetailsViewController.swift
//  Pyra
//  Created by Fauxly on 06.07.2026.

import UIKit

public final class PRPackageDetailsViewController: UIViewController {
    
    private let package: PRPackage
    
    // Элементы интерфейса
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let metaLabel = UILabel()
    private let descriptionTextView = UITextView()
    private let installButton = UIButton(type: .system)
    private let consoleLogTextView = UITextView() // Поле для вывода логов dpkg
    
    private var imageDownloadTask: URLSessionDataTask?
    
    private enum PackageState {
        case notInstalled
        case installed
        case updateAvailable(installedVersion: String)
    }
    private var packageState: PackageState = .notInstalled
    
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
        view.backgroundColor = .black
        
        setupLayout()
        configureData()
    }
    
    // Без этого Focus Engine на входе на экран сам выбирает ближайший фокусируемый элемент —
    // и им часто оказывается кнопка "УСТАНОВИТЬ", а не окно описания над ней. Из-за этого
    // длинное описание, не влезающее в свою высоту, оставалось непрочитанным: фокус просто
    // проскакивал мимо него сразу на кнопку. Явно указываем, что первым должно фокусироваться
    // именно описание — тогда можно пролистать его целиком, и только потом уйти вниз на кнопку.
    public override var preferredFocusEnvironments: [UIFocusEnvironment] {
        return [descriptionTextView]
    }
    
    private func setupLayout() {
        // 1. Левая колонка: Иконка и Мета-данные
        iconImageView.frame = CGRect(x: 100, y: 150, width: 350, height: 350)
        iconImageView.contentMode = .scaleAspectFill
        iconImageView.layer.cornerRadius = 24
        iconImageView.clipsToBounds = true
        view.addSubview(iconImageView)
        
        metaLabel.frame = CGRect(x: 100, y: 530, width: 350, height: 150)
        metaLabel.numberOfLines = 0
        metaLabel.textColor = .lightGray
        metaLabel.font = UIFont.systemFont(ofSize: 22, weight: .regular)
        metaLabel.textAlignment = .center
        view.addSubview(metaLabel)
        
        // 2. Правая колонка: Название и Описание
        // y сдвинут вниз (было 140) — освобождает место под кнопкой "Назад" в safe area сверху
        titleLabel.frame = CGRect(x: 520, y: 60, width: 1300, height: 60)
        titleLabel.textColor = .white
        titleLabel.font = UIFont.systemFont(ofSize: 48, weight: .bold)
        view.addSubview(titleLabel)
        
        descriptionTextView.frame = CGRect(x: 520, y: 140, width: 1300, height: 180)
        descriptionTextView.backgroundColor = .clear
        descriptionTextView.textColor = .darkGray
        descriptionTextView.font = UIFont.systemFont(ofSize: 24, weight: .regular)
        // isSelectable — именно это свойство делает UITextView фокусируемым и скроллящимся
        // через Focus Engine на tvOS. С false он превращается в статичный нескроллящийся текст,
        // на который в принципе нельзя навести фокус пультом.
        descriptionTextView.isSelectable = true
        descriptionTextView.isScrollEnabled = true
        descriptionTextView.showsVerticalScrollIndicator = true
        view.addSubview(descriptionTextView)
        
        // 3. Кнопка "УСТАНОВИТЬ" (сразу под описанием)
        installButton.frame = CGRect(x: 520, y: 340, width: 1300, height: 80)
        installButton.setTitle("PKG_DETAILS_INSTALL".localized, for: .normal)
        installButton.titleLabel?.font = UIFont.systemFont(ofSize: 28, weight: .bold)
        // Привязываем нажатие кнопки к нашей джейлбрейк-логике
        installButton.addTarget(self, action: #selector(installButtonTapped), for: .primaryActionTriggered)
        view.addSubview(installButton)
        
        // 4. Окно терминала для вывода логов dpkg/apt (внизу экрана)
        consoleLogTextView.frame = CGRect(x: 520, y: 460, width: 1300, height: 350)
        consoleLogTextView.backgroundColor = UIColor(white: 0.08, alpha: 1.0)
        consoleLogTextView.textColor = .green // Настоящий хакерский зеленый цвет логов
        consoleLogTextView.font = UIFont.monospacedSystemFont(ofSize: 18, weight: .regular)
        consoleLogTextView.layer.cornerRadius = 12
        consoleLogTextView.textContainerInset = UIEdgeInsets(top: 15, left: 15, bottom: 15, right: 15)
        // isSelectable у consoleLogTextView по умолчанию true (не трогали), поэтому лог
        // и так был скроллящимся — в отличие от descriptionTextView выше.
        consoleLogTextView.text = "PKG_DETAILS_WAITING".localized
        view.addSubview(consoleLogTextView)
    }
    
    private func configureData() {
        titleLabel.text = package.name
        
        // Определяем состояние пакета: не установлен / установлен / есть обновление
        if let installed = PRStatusParser.shared.readInstalledPackages().first(where: { $0.id.lowercased() == package.packageID.lowercased() }) {
            // Пакет с таким ID стоит — но может быть, мы смотрим на более новую версию
            if PRDependencyChecker.compareVersions(package.version, ">>", installed.version) {
                packageState = .updateAvailable(installedVersion: installed.version)
            } else {
                packageState = .installed
            }
        } else {
            packageState = .notInstalled
        }
        updateInstallButtonAppearance()
        
        // Формируем красивый блок мета-данных слева под иконкой
        let author = package.author ?? "PKG_DETAILS_UNKNOWN_AUTHOR".localized
        metaLabel.text = "\(package.packageID)\n"
            + "\("PKG_DETAILS_META_VERSION".localized): \(package.version)\n"
            + "\("PKG_DETAILS_META_AUTHOR".localized): \(author)\n"
            + "\("PKG_DETAILS_META_ARCH".localized): \(package.architecture)"
        
        // Подгружаем описание или зависимости
        if let depends = package.depends, !depends.isEmpty {
            descriptionTextView.text = "\(package.description)\n\n\("PKG_DETAILS_DEPENDENCIES".localized): \(depends)"
        } else {
            descriptionTextView.text = package.description
        }
        
        // Ставим правильную иконку или генерируем текстовую неоновую карточку
        if let iconStr = package.iconURL, !iconStr.isEmpty, let url = URL(string: iconStr) {
            imageDownloadTask = URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
                if let data = data, let image = UIImage(data: data) {
                    Task { @MainActor in
                        self?.iconImageView.image = image
                    }
                }
            }
            imageDownloadTask?.resume()
        } else {
            iconImageView.image = createPlaceholderCard(withTitle: package.name)
        }
    }
    
    /// Единая точка правды для вида кнопки — вызывается и при первой загрузке экрана,
    /// и после успешной установки/удаления, чтобы кнопка всегда отражала актуальное состояние.
    private func updateInstallButtonAppearance() {
        switch packageState {
        case .notInstalled:
            installButton.setTitle("PKG_DETAILS_INSTALL".localized, for: .normal)
            installButton.tintColor = nil
        case .installed:
            installButton.setTitle("PKG_DETAILS_UNINSTALL".localized, for: .normal)
            installButton.tintColor = .systemRed
        case .updateAvailable(let oldVersion):
            let title = String(format: "PKG_DETAILS_UPDATE".localized, oldVersion, package.version)
            installButton.setTitle(title, for: .normal)
            installButton.tintColor = PRTheme.brass
        }
        installButton.isEnabled = true
    }
    
    // Логика кнопки зависит от состояния пакета
    @objc private func installButtonTapped() {
        switch packageState {
        case .notInstalled:
            guard let repository = package.sourceRepository else {
                appendLog("PKG_DETAILS_ERROR_NO_REPO".localized + "\n")
                return
            }
            
            // Проверяем зависимости — если чего-то не хватает, показываем информационно
            // в логе. Блокировать установку не нужно: apt-get -f install подтянет их сам.
            let missing = PRDependencyChecker.missingDependencies(for: package)
            if !missing.isEmpty {
                let orWord = "PKG_DETAILS_OR".localized
                let list = missing.map { group in
                    group.map { $0.displayString }.joined(separator: " \(orWord) ")
                }.joined(separator: ", ")
                appendLog(String(format: "PKG_DETAILS_AUTO_DEPS_INFO".localized, list) + "\n")
            }
            
            startInstall(repository: repository)
            
        case .installed:
            confirmUninstall()
            
        case .updateAvailable:
            guard let repository = package.sourceRepository else {
                appendLog("PKG_DETAILS_ERROR_NO_REPO".localized + "\n")
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
        
        Task {
            do {
                let dpkgPath = PRPathManager.shared.makePath("/usr/bin/dpkg")
                let result = try await PRSpawn.runCommand(dpkgPath, arguments: ["-r", package.packageID], elevated: true)
                
                await MainActor.run {
                    if result.exitCode == 0 {
                        self.appendLog("\n" + String(format: "PKG_DETAILS_UNINSTALL_SUCCESS".localized, self.package.packageID) + "\n")
                        self.appendLog(result.stdout)
                        self.packageState = .notInstalled
                        self.updateInstallButtonAppearance()
                    } else {
                        self.appendLog("\n" + String(format: "PKG_DETAILS_DPKG_ERROR".localized, result.exitCode) + "\n")
                        self.appendLog(result.stderr)
                        self.installButton.isEnabled = true
                    }
                }
            } catch {
                await MainActor.run {
                    self.appendLog("\n" + "PKG_DETAILS_GENERIC_ERROR".localized + error.localizedDescription)
                    self.installButton.isEnabled = true
                }
            }
        }
    }
    
    private func startInstall(repository: PRRepository) {
        consoleLogTextView.text = String(format: "PKG_DETAILS_DOWNLOADING".localized, package.packageID) + "\n"
        installButton.isEnabled = false
        
        Task {
            do {
                let localURL = try await PRDownloadManager.shared.download(package: package, repository: repository)
                
                await MainActor.run {
                    self.appendLog(String(format: "PKG_DETAILS_DOWNLOADED".localized, localURL.lastPathComponent) + "\n")
                    self.appendLog("PKG_DETAILS_INSTALLING_VIA_DPKG".localized + "\n")
                }
                
                // Шаг 1: dpkg -i
                let dpkgPath = PRPathManager.shared.makePath("/usr/bin/dpkg")
                let result = try await PRSpawn.runCommand(dpkgPath, arguments: ["-i", localURL.path], elevated: true)
                
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
                
                // Шаг 3: ВЕРИФИКАЦИЯ — не доверяем exit code, проверяем реальный статус
                // в базе dpkg. apt-get -f может вернуть 0, ничего не сделав.
                let actuallyInstalled = PRStatusParser.shared.isPackageInstalled(id: self.package.packageID)
                
                await MainActor.run {
                    if actuallyInstalled {
                        self.appendLog("\n" + String(format: "PKG_DETAILS_SUCCESS".localized, self.package.packageID) + "\n")
                        self.packageState = .installed
                        self.updateInstallButtonAppearance()
                    } else {
                        self.appendLog("\n" + "PKG_DETAILS_INSTALL_FAILED_VERIFY".localized + "\n")
                        self.installButton.isEnabled = true
                    }
                    PRFileManager.shared.removeDownloadedFile(for: self.package)
                }
            } catch {
                await MainActor.run {
                    self.appendLog("\n" + "PKG_DETAILS_GENERIC_ERROR".localized + error.localizedDescription)
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
        let size = CGSize(width: 350, height: 350)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor(white: 0.15, alpha: 1.0).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center
            
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 30, weight: .bold),
                .foregroundColor: UIColor.white,
                .paragraphStyle: paragraphStyle
            ]
            
            let stringSize = title.boundingRect(with: CGSize(width: size.width - 40, height: size.height - 40), options: .usesLineFragmentOrigin, attributes: attributes, context: nil).size
            let textRect = CGRect(x: 20, y: (size.height - stringSize.height) / 2, width: size.width - 40, height: stringSize.height)
            title.draw(in: textRect, withAttributes: attributes)
        }
    }
}
