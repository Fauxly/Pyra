//
//  PRRepositoriesViewController.swift
//  Pyra
//
//  Created by Fauxly on 06.07.2026.
//

import UIKit

/// Источники — сетка карточек: первая "Добавить источник", дальше репозитории с иконкой,
/// адресом, числом пакетов и статусом загрузки. Удаление — долгое нажатие на карточку.
public final class PRRepositoriesViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {

    private var collectionView: UICollectionView!
    private let titleLabel = UILabel()
    private let refreshButton = PRActionButton()
    private let progressTrack = UIView()
    private let progressFill = UIView()
    private var progressAnimationRunning = false

    // Единственный источник правды — PRRepositoryManager. Больше никакого локального
    // дублирующего массива: то, что добавляется здесь, реально используется при загрузке пакетов.
    private var repositories: [PRRepository] {
        PRRepositoryManager.shared.repositories
    }

    /// Общий каталог — приходит из PRCustomTabBarController; по нему считаем пакеты в каждом источнике
    var allPackages: [PRPackage] = [] {
        didSet {
            hasLoadedCatalog = true
            packageCounts = Dictionary(grouping: allPackages.compactMap { $0.sourceRepository?.id }) { $0 }
                .mapValues { $0.count }
            collectionView?.reloadData()
        }
    }
    private var packageCounts: [UUID: Int] = [:]
    private var hasLoadedCatalog = false

    // Пока идёт сетевая загрузка каталога — показываем бегущую латунную полосу сверху
    private var isRefreshing = false {
        didSet {
            progressTrack.isHidden = !isRefreshing
            refreshButton.isEnabled = !isRefreshing
            if isRefreshing {
                startProgressAnimation()
            } else {
                stopProgressAnimation()
            }
        }
    }

    // Какие конкретно репозитории сейчас грузятся — для значка статуса на карточке
    private var loadingRepositoryIDs: Set<UUID> = []

    // Когда каждый репозиторий начал грузиться — чтобы гарантировать минимальное время показа
    // статуса "грузится". Без этого быстрые репозитории мелькали бы короче, чем человек успевает заметить.
    private var loadingStartTimes: [UUID: Date] = [:]
    private let minimumVisibleDuration: TimeInterval = 0.5

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = PRTheme.ink

        setupHeader()
        setupCollectionView()
        setupProgressBar()

        NotificationCenter.default.addObserver(self, selector: #selector(refreshDidStart),
                                               name: PRRepositoryManager.didStartRefreshingNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(refreshDidFinish),
                                               name: PRRepositoryManager.didFinishRefreshingNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(repositoryRefreshDidStart(_:)),
                                               name: PRRepositoryManager.repositoryDidStartRefreshingNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(repositoryRefreshDidFinish(_:)),
                                               name: PRRepositoryManager.repositoryDidFinishRefreshingNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(repositoriesDidChange),
                                               name: PRRepositoryManager.repositoriesDidChangeNotification, object: nil)
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateTitle()
    }

    // MARK: - Вёрстка

    private func setupHeader() {
        titleLabel.font = UIFont.systemFont(ofSize: 40, weight: .heavy)
        titleLabel.textColor = PRTheme.textPrimary
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)

        refreshButton.style = .secondary
        refreshButton.setImage(UIImage(systemName: "arrow.clockwise"), for: .normal)
        refreshButton.setTitle("SOURCES_REFRESH_ALL".localized, for: .normal)
        refreshButton.accessibilityLabel = "SOURCES_REFRESH_A11Y".localized
        refreshButton.addTarget(self, action: #selector(refreshTapped), for: .primaryActionTriggered)
        refreshButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(refreshButton)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 30),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: PRGridLayout.horizontalInset),

            refreshButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            refreshButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -PRGridLayout.horizontalInset),
            refreshButton.heightAnchor.constraint(equalToConstant: 66)
        ])
        updateTitle()
    }

    private func updateTitle() {
        titleLabel.text = String(format: "SOURCES_TITLE".localized, repositories.count)
    }

    private func setupCollectionView() {
        let layout = UICollectionViewCompositionalLayout { _, _ in
            PRGridLayout.section(columns: 3, itemHeight: 170)
        }
        collectionView = PRGridLayout.makeCollectionView(in: view, layout: layout)
        collectionView.register(PRSourceCell.self, forCellWithReuseIdentifier: PRSourceCell.reuseIdentifier)
        collectionView.register(PRAddSourceCell.self, forCellWithReuseIdentifier: PRAddSourceCell.reuseIdentifier)
        collectionView.dataSource = self
        collectionView.delegate = self
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    // MARK: - Уведомления менеджера

    @objc private func refreshDidStart() {
        isRefreshing = true
    }

    @objc private func refreshDidFinish() {
        isRefreshing = false
    }

    @objc private func repositoriesDidChange() {
        updateTitle()
        collectionView.reloadData()
    }

    @objc private func repositoryRefreshDidStart(_ notification: Notification) {
        guard let id = notification.userInfo?["repositoryID"] as? UUID else { return }
        loadingRepositoryIDs.insert(id)
        loadingStartTimes[id] = Date()
        reloadItem(for: id)
    }

    @objc private func repositoryRefreshDidFinish(_ notification: Notification) {
        guard let id = notification.userInfo?["repositoryID"] as? UUID else { return }

        let elapsed = loadingStartTimes[id].map { Date().timeIntervalSince($0) } ?? minimumVisibleDuration
        let remainingDelay = max(0, minimumVisibleDuration - elapsed)

        DispatchQueue.main.asyncAfter(deadline: .now() + remainingDelay) { [weak self] in
            guard let self else { return }
            self.loadingRepositoryIDs.remove(id)
            self.loadingStartTimes.removeValue(forKey: id)
            self.reloadItem(for: id)
        }
    }

    private func reloadItem(for repositoryID: UUID) {
        guard let index = repositories.firstIndex(where: { $0.id == repositoryID }) else { return }
        // reconfigureItems не сбрасывает фокус на карточке (в отличие от reloadItems)
        collectionView.reconfigureItems(at: [IndexPath(item: index + 1, section: 0)])
    }

    private func status(for repository: PRRepository) -> PRSourceCell.Status {
        if loadingRepositoryIDs.contains(repository.id) { return .loading }
        guard hasLoadedCatalog else { return .unknown }
        let count = packageCounts[repository.id] ?? 0
        return count > 0 ? .ready(packageCount: count) : .empty
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
    
    @objc private func refreshTapped() {
        PRRepositoryManager.shared.requestRefresh()
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
                self?.collectionView.reloadData()
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
    
    // MARK: - UICollectionViewDataSource

    // Элемент 0 — карточка "Добавить", дальше источники (индекс источника = item - 1)
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        repositories.count + 1
    }

    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if indexPath.item == 0 {
            return collectionView.dequeueReusableCell(withReuseIdentifier: PRAddSourceCell.reuseIdentifier, for: indexPath)
        }
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PRSourceCell.reuseIdentifier, for: indexPath) as? PRSourceCell else {
            return UICollectionViewCell()
        }
        let repository = repositories[indexPath.item - 1]
        cell.configure(with: repository, status: status(for: repository))
        return cell
    }

    // MARK: - UICollectionViewDelegate

    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard indexPath.item > 0 else {
            addRepositoryTapped()
            return
        }
        let repository = repositories[indexPath.item - 1]

        // Экран раздела: шапка с иконкой репозитория + сетка пакетов по категориям.
        // Пакеты тянем именно из этого репозитория напрямую, а не из смёрженного каталога —
        // иначе не отличить, что откуда пришло. Пока грузится — скелетоны.
        let repositoryVC = PRPackageListViewController(mode: .repository(repository))
        repositoryVC.showLoading()
        navigationController?.pushViewController(repositoryVC, animated: true)

        Task {
            do {
                let packages = try await PRNetworkManager.shared.fetchPackages(from: repository)
                await MainActor.run {
                    repositoryVC.setPackages(packages)
                }
            } catch {
                print("Pyra: Не удалось загрузить \(repository.name) (\(repository.packagesURL.absoluteString)): \(error.localizedDescription)")
                await MainActor.run {
                    repositoryVC.setPackages([])
                }
            }
        }
    }

    // Долгое нажатие (удержание тач-панели пульта) — контекстное меню с удалением источника.
    // UIContextMenuConfiguration на tvOS есть только с 17.0 — на более старых системах
    // метод просто не вызывается, а сборка с меньшим минимальным tvOS не ломается.
    @available(tvOS 17.0, *)
    public func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemsAt indexPaths: [IndexPath], point: CGPoint) -> UIContextMenuConfiguration? {
        guard let indexPath = indexPaths.first, indexPath.item > 0 else { return nil }
        let repository = repositories[indexPath.item - 1]

        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            let deleteAction = UIAction(title: "SOURCES_DELETE_ACTION".localized, image: UIImage(systemName: "trash"), attributes: .destructive) { _ in
                PRRepositoryManager.shared.removeRepository(repository)
                self?.updateTitle()
                self?.collectionView.reloadData()
            }
            return UIMenu(title: repository.name, children: [deleteAction])
        }
    }
}
