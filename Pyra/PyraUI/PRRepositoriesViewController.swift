//
//  PRRepositoriesViewController.swift
//  Pyra
//
//  Created by Fix’s Trick’s on 07.07.2026.
//

import UIKit

public final class PRRepositoriesViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let progressTrack = UIView()
    private let progressFill = UIView()
    private var progressAnimationRunning = false
    
    // Единственный источник правды — PRRepositoryManager. Больше никакого локального
    // дублирующего массива: то, что добавляется здесь, реально используется при загрузке пакетов.
    private var repositories: [PRRepository] {
        PRRepositoryManager.shared.repositories
    }
    
    // Пока идёт сетевая загрузка каталога — показываем бегущую латунную полосу сверху
    private var isRefreshing = false {
        didSet {
            progressTrack.isHidden = !isRefreshing
            if isRefreshing {
                startProgressAnimation()
            } else {
                stopProgressAnimation()
            }
        }
    }
    
    // Какие конкретно репозитории сейчас грузятся — для мини-полосы на отдельной строке
    private var loadingRepositoryIDs: Set<UUID> = []
    
    // Когда каждый репозиторий начал грузиться — чтобы гарантировать минимальное время показа
    // мини-полосы. Без этого быстрые репозитории (ответ за доли секунды) мелькали бы короче,
    // чем человек успевает заметить — и казалось бы, что работает только общая полоса сверху.
    private var loadingStartTimes: [UUID: Date] = [:]
    private let minimumVisibleDuration: TimeInterval = 0.5
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = PRTheme.ink
        
        setupTableHeader()
        setupTableView()
        setupProgressBar()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshDidStart),
            name: PRRepositoryManager.didStartRefreshingNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshDidFinish),
            name: PRRepositoryManager.didFinishRefreshingNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(repositoryRefreshDidStart(_:)),
            name: PRRepositoryManager.repositoryDidStartRefreshingNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(repositoryRefreshDidFinish(_:)),
            name: PRRepositoryManager.repositoryDidFinishRefreshingNotification,
            object: nil
        )
    }
    
    @objc private func refreshDidStart() {
        isRefreshing = true
    }
    
    @objc private func refreshDidFinish() {
        isRefreshing = false
    }
    
    @objc private func repositoryRefreshDidStart(_ notification: Notification) {
        guard let id = notification.userInfo?["repositoryID"] as? UUID else { return }
        loadingRepositoryIDs.insert(id)
        loadingStartTimes[id] = Date()
        reloadRow(for: id)
    }
    
    @objc private func repositoryRefreshDidFinish(_ notification: Notification) {
        guard let id = notification.userInfo?["repositoryID"] as? UUID else { return }
        
        let elapsed = loadingStartTimes[id].map { Date().timeIntervalSince($0) } ?? minimumVisibleDuration
        let remainingDelay = max(0, minimumVisibleDuration - elapsed)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + remainingDelay) { [weak self] in
            guard let self else { return }
            self.loadingRepositoryIDs.remove(id)
            self.loadingStartTimes.removeValue(forKey: id)
            self.reloadRow(for: id)
        }
    }
    
    private func reloadRow(for repositoryID: UUID) {
        guard let index = repositories.firstIndex(where: { $0.id == repositoryID }) else { return }
        // reconfigureRows не сбрасывает фокус на строке (в отличие от reloadRows) — важно,
        // раз обновление может прилететь, пока пользователь уже листает список пультом
        if #available(tvOS 15.0, *) {
            tableView.reconfigureRows(at: [IndexPath(row: index, section: 0)])
        } else {
            tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .none)
        }
    }
    
    // MARK: - Прогресс-бар обновления
    
    private func setupProgressBar() {
        progressTrack.backgroundColor = PRTheme.surface
        progressTrack.layer.cornerRadius = 3
        progressTrack.clipsToBounds = true
        progressTrack.isHidden = true
        progressTrack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(progressTrack)
        
        progressFill.backgroundColor = PRTheme.brass
        progressFill.layer.cornerRadius = 3
        progressTrack.addSubview(progressFill)
        
        NSLayoutConstraint.activate([
            progressTrack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 4),
            progressTrack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 60),
            progressTrack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -60),
            progressTrack.heightAnchor.constraint(equalToConstant: 6)
        ])
    }
    
    /// Индикатор неопределённой длительности ("бегущая полоса") — у нас нет реального процента
    /// прогресса по сети (несколько репозиториев качаются параллельно), поэтому честнее показать
    /// зацикленную анимацию, а не выдумывать проценты, которых на самом деле не считаем.
    private func startProgressAnimation() {
        guard !progressAnimationRunning else { return }
        progressAnimationRunning = true
        
        progressTrack.layoutIfNeeded()
        let trackWidth = progressTrack.bounds.width
        let fillWidth = max(trackWidth * 0.28, 40)
        
        progressFill.frame = CGRect(x: -fillWidth, y: 0, width: fillWidth, height: 6)
        
        animateProgressPass(trackWidth: trackWidth, fillWidth: fillWidth)
    }
    
    private func animateProgressPass(trackWidth: CGFloat, fillWidth: CGFloat) {
        guard progressAnimationRunning else { return }
        
        progressFill.frame = CGRect(x: -fillWidth, y: 0, width: fillWidth, height: 6)
        
        UIView.animate(
            withDuration: 1.1,
            delay: 0,
            options: [.curveEaseInOut],
            animations: {
                self.progressFill.frame = CGRect(x: trackWidth, y: 0, width: fillWidth, height: 6)
            },
            completion: { [weak self] _ in
                guard let self, self.progressAnimationRunning else { return }
                self.animateProgressPass(trackWidth: trackWidth, fillWidth: fillWidth)
            }
        )
    }
    
    private func stopProgressAnimation() {
        progressAnimationRunning = false
        progressFill.layer.removeAllAnimations()
    }
    
    private func setupTableHeader() {
        // Верхняя панель с двумя круглыми иконками: "+" (добавить) и обновление
        let headerView = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 150))
        
        let addButton = makeIconButton(systemName: "plus", accessibilityLabel: "SOURCES_ADD_A11Y".localized)
        addButton.frame = CGRect(x: 100, y: 40, width: 70, height: 70)
        addButton.addTarget(self, action: #selector(addRepositoryTapped), for: .primaryActionTriggered)
        
        let refreshButton = makeIconButton(systemName: "arrow.clockwise", accessibilityLabel: "SOURCES_REFRESH_A11Y".localized)
        refreshButton.frame = CGRect(x: 190, y: 40, width: 70, height: 70)
        refreshButton.addTarget(self, action: #selector(refreshTapped), for: .primaryActionTriggered)
        
        headerView.addSubview(addButton)
        headerView.addSubview(refreshButton)
        tableView.tableHeaderView = headerView
    }
    
    private func makeIconButton(systemName: String, accessibilityLabel: String) -> UIButton {
        let button = UIButton(type: .system)
        button.accessibilityLabel = accessibilityLabel
        button.backgroundColor = .clear
        button.layer.cornerRadius = 12
        button.layer.borderWidth = 2
        button.layer.borderColor = PRTheme.brass.cgColor
        
        // Явный UIImageView вместо button.setImage(...) — на tvOS встроенный imageView
        // кнопки без текста рендерился ненадёжно (иконка не появлялась вообще).
        let config = UIImage.SymbolConfiguration(pointSize: 28, weight: .semibold)
        let iconView = UIImageView(image: UIImage(systemName: systemName, withConfiguration: config))
        iconView.tintColor = PRTheme.brass
        iconView.contentMode = .scaleAspectFit
        iconView.isUserInteractionEnabled = false
        iconView.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(iconView)
        
        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 32),
            iconView.heightAnchor.constraint(equalToConstant: 32)
        ])
        
        return button
    }
    
    @objc private func refreshTapped() {
        PRRepositoryManager.shared.requestRefresh()
    }
    
    private func setupTableView() {
        // Таблица под кнопку
        tableView.frame = view.bounds
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tableView.backgroundColor = .clear
        tableView.dataSource = self
        tableView.delegate = self
        
        tableView.register(PRRepositoryCell.self, forCellReuseIdentifier: PRRepositoryCell.reuseIdentifier)
        view.addSubview(tableView)
    }
    
    @objc private func addRepositoryTapped() {
        // Своя клавиатура на экране вместо системного UIAlertController.addTextField() —
        // системная клавиатура зависает на этом устройстве вне зависимости от entitlements,
        // архитектуры запуска (SwiftUI/чистый UIKit) и нашего кастомного фокус-кода.
        // Похоже на проблему уровня самого джейлбрейка, а не кода Pyra — см. обсуждение.
        let keyboardVC = PRAddRepositoryViewController()
        keyboardVC.modalPresentationStyle = .fullScreen
        
        keyboardVC.onSubmit = { [weak self] urlText in
            guard !urlText.isEmpty else { return }
            
            let normalized = urlText.hasPrefix("http://") || urlText.hasPrefix("https://") ? urlText : "https://\(urlText)"
            
            guard let url = URL(string: normalized), let host = url.host else {
                self?.showSimpleAlert(title: "COMMON_ERROR".localized, message: "SOURCES_INVALID_URL".localized)
                return
            }
            
            let repository = PRRepository(name: host, baseURL: url)
            let added = PRRepositoryManager.shared.addRepository(repository)
            
            if added {
                self?.tableView.reloadData()
            } else {
                self?.showSimpleAlert(title: "SOURCES_ALREADY_ADDED_TITLE".localized, message: "SOURCES_ALREADY_ADDED_MESSAGE".localized)
            }
        }
        
        present(keyboardVC, animated: true, completion: nil)
    }
    
    private func showSimpleAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "COMMON_OK".localized, style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
    // MARK: - UITableViewDataSource
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return repositories.count
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: PRRepositoryCell.reuseIdentifier, for: indexPath) as? PRRepositoryCell ?? PRRepositoryCell(style: .subtitle, reuseIdentifier: PRRepositoryCell.reuseIdentifier)
        cell.backgroundColor = .clear
        
        let repository = repositories[indexPath.row]
        cell.setLoading(loadingRepositoryIDs.contains(repository.id))
        
        let focusBackground = UIView()
        focusBackground.backgroundColor = PRTheme.surfaceFocused
        focusBackground.layer.cornerRadius = 8
        cell.selectedBackgroundView = focusBackground
        
        if #available(tvOS 14.0, *) {
            var content = cell.defaultContentConfiguration()
            content.text = repository.name
            content.secondaryText = repository.baseURL.host?.contains("procurs.us") == true ? "SOURCES_OFFICIAL".localized : repository.baseURL.absoluteString
            content.textProperties.color = PRTheme.textPrimary
            content.textProperties.font = UIFont.systemFont(ofSize: 26, weight: .medium)
            content.textProperties.numberOfLines = 1
            content.textProperties.lineBreakMode = .byTruncatingTail
            content.secondaryTextProperties.color = PRTheme.textSecondary
            content.secondaryTextProperties.numberOfLines = 1
            // Middle-усечение для URL — сохраняет и схему (https://), и конец домена видимыми,
            // это полезнее, чем byTruncatingTail, который бы просто съел конец адреса.
            content.secondaryTextProperties.lineBreakMode = .byTruncatingMiddle
            cell.contentConfiguration = content
        } else {
            cell.textLabel?.text = repository.name
            cell.textLabel?.textColor = PRTheme.textPrimary
            cell.textLabel?.lineBreakMode = .byTruncatingTail
            cell.detailTextLabel?.lineBreakMode = .byTruncatingMiddle
        }
        
        return cell
    }
    
    // MARK: - UITableViewDelegate
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let repository = repositories[indexPath.row]
        
        // Переходим внутрь конкретного репозитория — переиспользуем PRDashboardViewController
        // как и для категорий. Помечаем "кастомный список" СРАЗУ пустым массивом — иначе
        // viewDidLoad успевает сработать раньше, чем придёт ответ сети, решит что кастомного
        // списка не будет, и сам вызовет loadData() (общий смёрженный каталог, где Procursus
        // почти всегда доминирует по числу пакетов) — из-за этого всегда показывался Procursus
        // вне зависимости от того, по какому репозиторию реально тапнули.
        let repoDetailsVC = PRDashboardViewController()
        repoDetailsVC.title = repository.name
        repoDetailsVC.setCustomPackages([])
        navigationController?.pushViewController(repoDetailsVC, animated: true)
        
        Task {
            // Намеренно смотрим именно в этот репозиторий напрямую, а не в уже смёрженный
            // общий каталог всех репозиториев — иначе не отличить, что откуда пришло.
            do {
                let packages = try await PRNetworkManager.shared.fetchPackages(from: repository)
                await MainActor.run {
                    repoDetailsVC.setCustomPackages(packages)
                }
            } catch {
                print("Pyra: Не удалось загрузить \(repository.name) (\(repository.packagesURL.absoluteString)): \(error.localizedDescription)")
                await MainActor.run {
                    repoDetailsVC.setCustomPackages([])
                }
            }
        }
    }
    
    // Долгое нажатие (удержание тач-панели пульта) — стандартный tvOS-способ показать
    // контекстное меню действий, не занимая обычный тап под второстепенное действие.
    public func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        let repository = repositories[indexPath.row]
        
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            let deleteAction = UIAction(title: "SOURCES_DELETE_ACTION".localized, image: UIImage(systemName: "trash"), attributes: .destructive) { _ in
                PRRepositoryManager.shared.removeRepository(repository)
                self?.tableView.reloadData()
            }
            return UIMenu(title: repository.name, children: [deleteAction])
        }
    }
    
    // tvOS для .grouped таблиц сам поднимает сфокусированную строку в виде светлой карточки
    // и наш selectedBackgroundView эту подложку не перекрывает — поэтому вместо борьбы с фоном
    // переключаем цвет текста: тёмный на фокусе (светлая карточка), светлый в состоянии покоя.
    public func tableView(_ tableView: UITableView, didUpdateFocusIn context: UITableViewFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        if let nextIndexPath = context.nextFocusedIndexPath,
           let cell = tableView.cellForRow(at: nextIndexPath) {
            coordinator.addCoordinatedAnimations({
                self.applyTextColor(to: cell, primary: PRTheme.ink, secondary: PRTheme.ink.withAlphaComponent(0.7))
            }, completion: nil)
        }
        
        if let previousIndexPath = context.previouslyFocusedIndexPath,
           let cell = tableView.cellForRow(at: previousIndexPath) {
            coordinator.addCoordinatedAnimations({
                self.applyTextColor(to: cell, primary: PRTheme.textPrimary, secondary: PRTheme.textSecondary)
            }, completion: nil)
        }
    }
    
    private func applyTextColor(to cell: UITableViewCell, primary: UIColor, secondary: UIColor) {
        if #available(tvOS 14.0, *), var content = cell.contentConfiguration as? UIListContentConfiguration {
            content.textProperties.color = primary
            content.secondaryTextProperties.color = secondary
            cell.contentConfiguration = content
        } else {
            cell.textLabel?.textColor = primary
        }
    }
    
    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 120
    }
}
