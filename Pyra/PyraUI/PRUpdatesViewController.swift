//
//  PRUpdatesViewController.swift
//  Pyra
//  Created by Fauxly on 06.07.2026.

import UIKit

/// Вкладка "Обновления": сверху сводка (сколько обновлений, сколько качать, "Обновить всё"),
/// ниже широкие карточки в две колонки с версиями "было → станет". Нажатие на карточку —
/// карточка пакета с готовой кнопкой "Обновить".
public final class PRUpdatesViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {

    private var collectionView: UICollectionView!
    private let emptyStack = UIStackView()

    private struct UpdateItem {
        let installed: PRInstalledPackage
        let available: PRPackage
    }

    private var updates: [UpdateItem] = []

    // Сводка сверху
    private let summaryCard = UIView()
    private let summaryTitleLabel = UILabel()
    private let summarySubtitleLabel = UILabel()
    private let updateAllButton = PRActionButton()
    private let batchStatusLabel = UILabel()
    private var isUpdatingAll = false

    /// Вызывается после каждого пересчёта списка — PRCustomTabBarController вешает сюда
    /// обновление бейджа на кнопке вкладки
    var onUpdatesCountChange: ((Int) -> Void)?

    /// Полный каталог из всех репозиториев — приходит извне из PRCustomTabBarController.
    var allPackages: [PRPackage] = [] {
        didSet { rebuildUpdatesList() }
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = PRTheme.ink
        setupSummary()
        setupCollectionView()
        setupEmptyState()
        rebuildUpdatesList()
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Каждый раз при заходе на вкладку перечитываем dpkg status —
        // пользователь мог установить/обновить что-то с другого экрана.
        rebuildUpdatesList()
    }

    // MARK: - Вёрстка

    private func setupSummary() {
        summaryCard.backgroundColor = PRTheme.surface
        summaryCard.layer.cornerRadius = 28
        summaryCard.layer.cornerCurve = .continuous
        summaryCard.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(summaryCard)

        let glow = PRGradientView()
        glow.gradientLayer.colors = [PRTheme.brass.withAlphaComponent(0.22).cgColor, PRTheme.brass.withAlphaComponent(0).cgColor]
        glow.gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        glow.gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        glow.layer.cornerRadius = 28
        glow.clipsToBounds = true
        glow.isUserInteractionEnabled = false
        glow.translatesAutoresizingMaskIntoConstraints = false
        summaryCard.addSubview(glow)

        let icon = UIImageView(image: UIImage(systemName: "arrow.down.app.fill"))
        icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 56, weight: .semibold)
        icon.tintColor = PRTheme.brass
        icon.translatesAutoresizingMaskIntoConstraints = false
        summaryCard.addSubview(icon)

        summaryTitleLabel.font = UIFont.systemFont(ofSize: 40, weight: .heavy)
        summaryTitleLabel.textColor = PRTheme.textPrimary
        summarySubtitleLabel.font = UIFont.systemFont(ofSize: 24, weight: .medium)
        summarySubtitleLabel.textColor = PRTheme.textSecondary

        let textStack = UIStackView(arrangedSubviews: [summaryTitleLabel, summarySubtitleLabel])
        textStack.axis = .vertical
        textStack.spacing = 4
        textStack.translatesAutoresizingMaskIntoConstraints = false
        summaryCard.addSubview(textStack)

        updateAllButton.setImage(UIImage(systemName: "arrow.triangle.2.circlepath"), for: .normal)
        updateAllButton.addTarget(self, action: #selector(updateAllTapped), for: .primaryActionTriggered)
        updateAllButton.translatesAutoresizingMaskIntoConstraints = false
        summaryCard.addSubview(updateAllButton)

        batchStatusLabel.font = UIFont.systemFont(ofSize: 22, weight: .medium)
        batchStatusLabel.textColor = PRTheme.brass
        batchStatusLabel.textAlignment = .right
        batchStatusLabel.translatesAutoresizingMaskIntoConstraints = false
        summaryCard.addSubview(batchStatusLabel)

        NSLayoutConstraint.activate([
            summaryCard.topAnchor.constraint(equalTo: view.topAnchor, constant: 24),
            summaryCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: PRGridLayout.horizontalInset),
            summaryCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -PRGridLayout.horizontalInset),
            summaryCard.heightAnchor.constraint(equalToConstant: 160),

            glow.topAnchor.constraint(equalTo: summaryCard.topAnchor),
            glow.bottomAnchor.constraint(equalTo: summaryCard.bottomAnchor),
            glow.leadingAnchor.constraint(equalTo: summaryCard.leadingAnchor),
            glow.trailingAnchor.constraint(equalTo: summaryCard.trailingAnchor),

            icon.leadingAnchor.constraint(equalTo: summaryCard.leadingAnchor, constant: 40),
            icon.centerYAnchor.constraint(equalTo: summaryCard.centerYAnchor),

            textStack.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 30),
            textStack.centerYAnchor.constraint(equalTo: summaryCard.centerYAnchor),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: batchStatusLabel.leadingAnchor, constant: -30),

            updateAllButton.trailingAnchor.constraint(equalTo: summaryCard.trailingAnchor, constant: -40),
            updateAllButton.centerYAnchor.constraint(equalTo: summaryCard.centerYAnchor),
            updateAllButton.heightAnchor.constraint(equalToConstant: 80),

            batchStatusLabel.trailingAnchor.constraint(equalTo: updateAllButton.leadingAnchor, constant: -30),
            batchStatusLabel.centerYAnchor.constraint(equalTo: summaryCard.centerYAnchor),
            batchStatusLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 520)
        ])
    }

    private func setupCollectionView() {
        let layout = UICollectionViewCompositionalLayout { _, _ in
            PRGridLayout.section(columns: 2, itemHeight: 170, spacing: 36, topInset: 30)
        }
        collectionView = PRGridLayout.makeCollectionView(in: view, layout: layout)
        collectionView.register(PRUpdateCell.self, forCellWithReuseIdentifier: PRUpdateCell.reuseIdentifier)
        collectionView.dataSource = self
        collectionView.delegate = self
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: summaryCard.bottomAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    /// Пусто — большая бирюзовая галочка и "Все пакеты актуальны" вместо пустой сетки
    private func setupEmptyState() {
        let icon = UIImageView(image: UIImage(systemName: "checkmark.seal.fill"))
        icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 110, weight: .semibold)
        icon.tintColor = PRTheme.teal

        let label = UILabel()
        label.text = "UPDATES_EMPTY".localized
        label.textColor = PRTheme.textPrimary
        label.font = UIFont.systemFont(ofSize: 34, weight: .bold)

        emptyStack.addArrangedSubview(icon)
        emptyStack.addArrangedSubview(label)
        emptyStack.axis = .vertical
        emptyStack.alignment = .center
        emptyStack.spacing = 24
        emptyStack.isHidden = true
        emptyStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyStack)
        NSLayoutConstraint.activate([
            emptyStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStack.centerYAnchor.constraint(equalTo: collectionView.centerYAnchor)
        ])
    }

    private func updateHeader() {
        guard isViewLoaded else { return }
        summaryTitleLabel.text = updates.isEmpty
            ? "UPDATES_EMPTY".localized
            : String(format: "UPDATES_SUMMARY_TITLE".localized, updates.count)

        let totalSize = updates.compactMap { $0.available.size }.reduce(0, +)
        if totalSize > 0 {
            let formatter = ByteCountFormatter()
            formatter.countStyle = .file
            summarySubtitleLabel.text = String(format: "UPDATES_SUMMARY_SIZE".localized, formatter.string(fromByteCount: totalSize))
        } else {
            summarySubtitleLabel.text = nil
        }

        guard !isUpdatingAll else { return }
        updateAllButton.setTitle("UPDATES_UPDATE_ALL_SHORT".localized, for: .normal)
        updateAllButton.isEnabled = !updates.isEmpty
    }

    // MARK: - Обновить всё

    @objc private func updateAllTapped() {
        guard !isUpdatingAll, !updates.isEmpty else { return }
        let items = updates
        isUpdatingAll = true
        updateAllButton.isEnabled = false

        Task {
            var failed: [String] = []
            let dpkgPath = PRPathManager.shared.makePath("/usr/bin/dpkg")

            for (index, item) in items.enumerated() {
                await MainActor.run {
                    self.batchStatusLabel.text = String(
                        format: "UPDATES_PROGRESS".localized,
                        index + 1, items.count, item.installed.name
                    )
                }

                guard let repository = item.available.sourceRepository else {
                    failed.append(item.installed.name)
                    continue
                }

                do {
                    // Тот же путь, что и в карточке пакета: dpkg -i, при провале зависимостей —
                    // --force-depends, а итог проверяем по базе dpkg, не по exit code
                    let localURL = try await PRDownloadManager.shared.download(package: item.available, repository: repository)
                    let result = try await PRSpawn.runCommand(dpkgPath, arguments: ["--force-architecture", "-i", localURL.path], elevated: true)
                    if result.exitCode != 0 {
                        _ = try await PRSpawn.runCommand(dpkgPath, arguments: ["-i", "--force-depends", localURL.path], elevated: true)
                    }
                    PRFileManager.shared.removeDownloadedFile(for: item.available)

                    let installedNow = PRStatusParser.shared.readInstalledPackages()
                        .first { $0.id.lowercased() == item.installed.id.lowercased() }?.version
                    let isUpToDate = installedNow.map {
                        PRDependencyChecker.compareVersions($0, ">=", item.available.version)
                    } ?? false
                    if !isUpToDate {
                        failed.append(item.installed.name)
                    }
                } catch {
                    failed.append(item.installed.name)
                }
            }

            await MainActor.run {
                self.isUpdatingAll = false
                PRInstalledState.shared.refresh()
                self.rebuildUpdatesList()

                let updatedCount = items.count - failed.count
                self.batchStatusLabel.text = failed.isEmpty
                    ? String(format: "UPDATES_DONE".localized, updatedCount)
                    : String(format: "UPDATES_DONE_WITH_ERRORS".localized, updatedCount, failed.joined(separator: ", "))
            }
        }
    }

    private func rebuildUpdatesList() {
        let installed = PRStatusParser.shared.readInstalledPackages()

        updates = installed.compactMap { pkg in
            // Находим максимальную доступную версию этого пакета в каталоге
            guard let latest = allPackages
                .filter({ $0.packageID == pkg.id })
                .max(where: { PRDependencyChecker.compareVersions($0.version, "<<", $1.version) })
            else { return nil }

            // Только если реально новее установленной
            guard PRDependencyChecker.compareVersions(latest.version, ">>", pkg.version) else { return nil }

            return UpdateItem(installed: pkg, available: latest)
        }

        onUpdatesCountChange?(updates.count)
        updateHeader()

        collectionView?.reloadData()
        emptyStack.isHidden = !updates.isEmpty
        collectionView?.isHidden = updates.isEmpty
    }

    // MARK: - UICollectionViewDataSource

    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        updates.count
    }

    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PRUpdateCell.reuseIdentifier, for: indexPath) as? PRUpdateCell else {
            return UICollectionViewCell()
        }
        let item = updates[indexPath.item]
        cell.configure(name: item.installed.name, installedVersion: item.installed.version, available: item.available)
        return cell
    }

    // MARK: - UICollectionViewDelegate

    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let item = updates[indexPath.item]
        navigationController?.pushViewController(PRPackageDetailsViewController(package: item.available), animated: true)
    }
}

// MARK: - Array max helper

private extension Array {
    func max(where comparator: (Element, Element) -> Bool) -> Element? {
        guard !isEmpty else { return nil }
        return self.reduce(self[0]) { comparator($0, $1) ? $1 : $0 }
    }
}
