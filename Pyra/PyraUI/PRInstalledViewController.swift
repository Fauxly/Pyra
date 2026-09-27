//
//  PRInstalledViewController.swift
//  Pyra
//
//  Created by Fauxly on 06.07.2026.
//

import UIKit

/// Установленные — сверху плашки статистики (сколько стоит, сколько обновлений, сколько
/// занимают), ниже сетка плиток: сначала твики и приложения из подключённых источников
/// (с иконками, пакеты с обновлением — первыми), затем системные пакеты бутстрапа.
/// Нажатие открывает карточку пакета — там же удаление/обновление с шагами и логом.
public final class PRInstalledViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {

    private struct Section {
        let title: String
        let packages: [PRPackage]
    }

    private var collectionView: UICollectionView!
    private var sections: [Section] = []

    private let installedTile = PRStatTileView(caption: "INSTALLED_STAT_COUNT".localized)
    private let updatesTile = PRStatTileView(caption: "INSTALLED_STAT_UPDATES".localized, valueColor: PRTheme.brass)
    private let sizeTile = PRStatTileView(caption: "INSTALLED_STAT_SIZE".localized)

    /// Полный смёрженный каталог из всех репозиториев — приходит извне из PRCustomTabBarController,
    /// сама эта вкладка в сеть не ходит. Нужен для иконок и сравнения версий.
    var allPackages: [PRPackage] = [] {
        didSet { if isViewLoaded { reload() } }
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = PRTheme.ink

        let statsRow = UIStackView(arrangedSubviews: [installedTile, updatesTile, sizeTile])
        statsRow.axis = .horizontal
        statsRow.spacing = 36
        statsRow.distribution = .fillEqually
        statsRow.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statsRow)

        let layout = UICollectionViewCompositionalLayout { _, _ in
            PRGridLayout.section(columns: 5, itemHeight: 260, spacing: 30, header: true, topInset: 10)
        }
        collectionView = PRGridLayout.makeCollectionView(in: view, layout: layout)
        collectionView.register(PRPackageCell.self, forCellWithReuseIdentifier: PRPackageCell.reuseIdentifier)
        collectionView.register(PRSectionHeaderView.self,
                                forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
                                withReuseIdentifier: PRSectionHeaderView.reuseIdentifier)
        collectionView.dataSource = self
        collectionView.delegate = self

        NSLayoutConstraint.activate([
            statsRow.topAnchor.constraint(equalTo: view.topAnchor, constant: 24),
            statsRow.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: PRGridLayout.horizontalInset),
            statsRow.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -PRGridLayout.horizontalInset),
            statsRow.heightAnchor.constraint(equalToConstant: 120),

            collectionView.topAnchor.constraint(equalTo: statsRow.bottomAnchor, constant: 16),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        // Установили/удалили что-то на другом экране — пересобираем список
        NotificationCenter.default.addObserver(self, selector: #selector(installedStateDidChange),
                                               name: PRInstalledState.didChangeNotification, object: nil)
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reload()
    }

    @objc private func installedStateDidChange() {
        if isViewLoaded { reload() }
    }

    // MARK: - Данные

    private func reload() {
        let installed = PRStatusParser.shared.readInstalledPackages()

        // Самая новая версия каждого пакета в каталоге — для иконки и статуса обновления
        var latestByID: [String: PRPackage] = [:]
        for package in allPackages {
            let key = package.packageID.lowercased()
            if let existing = latestByID[key],
               !PRDependencyChecker.compareVersions(package.version, ">>", existing.version) {
                continue
            }
            latestByID[key] = package
        }

        var fromSources: [(package: PRPackage, hasUpdate: Bool)] = []
        var system: [PRPackage] = []
        var updatesCount = 0
        var totalKB: Int64 = 0

        for item in installed {
            totalKB += item.installedSizeKB ?? 0
            if let latest = latestByID[item.id.lowercased()] {
                let hasUpdate = PRDependencyChecker.compareVersions(latest.version, ">>", item.version)
                if hasUpdate { updatesCount += 1 }
                fromSources.append((latest, hasUpdate))
            } else {
                // Пакета нет ни в одном источнике (обычно — пакеты бутстрапа). Собираем модель
                // из dpkg status, чтобы плитка и карточка (с удалением) всё равно работали.
                system.append(PRPackage(
                    packageID: item.id,
                    name: item.name,
                    version: item.version,
                    description: item.description,
                    section: item.section.isEmpty ? "Unknown" : item.section,
                    installedSizeKB: item.installedSizeKB
                ))
            }
        }

        fromSources.sort {
            $0.hasUpdate != $1.hasUpdate
                ? $0.hasUpdate
                : $0.package.name.localizedCaseInsensitiveCompare($1.package.name) == .orderedAscending
        }

        if allPackages.isEmpty {
            // Каталог ещё не загружен — не можем отличить твики от системных, показываем всё одной секцией
            sections = [Section(title: "INSTALLED_SECTION_ALL".localized, packages: system)]
        } else {
            sections = [
                Section(title: "INSTALLED_SECTION_SOURCES".localized, packages: fromSources.map { $0.package }),
                Section(title: "INSTALLED_SECTION_SYSTEM".localized, packages: system)
            ].filter { !$0.packages.isEmpty }
        }

        installedTile.value = "\(installed.count)"
        updatesTile.value = "\(updatesCount)"
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        sizeTile.value = totalKB > 0 ? formatter.string(fromByteCount: totalKB * 1024) : "—"

        collectionView.reloadData()
    }

    // MARK: - UICollectionViewDataSource

    public func numberOfSections(in collectionView: UICollectionView) -> Int {
        sections.count
    }

    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        sections[section].packages.count
    }

    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PRPackageCell.reuseIdentifier, for: indexPath) as? PRPackageCell else {
            return UICollectionViewCell()
        }
        cell.configure(with: sections[indexPath.section].packages[indexPath.item])
        return cell
    }

    public func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        guard let header = collectionView.dequeueReusableSupplementaryView(
            ofKind: kind, withReuseIdentifier: PRSectionHeaderView.reuseIdentifier, for: indexPath
        ) as? PRSectionHeaderView else {
            return UICollectionReusableView()
        }
        let section = sections[indexPath.section]
        header.leadingInset = PRGridLayout.horizontalInset
        header.configure(title: "\(section.title)  ·  \(section.packages.count)")
        return header
    }

    // MARK: - UICollectionViewDelegate

    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let package = sections[indexPath.section].packages[indexPath.item]
        navigationController?.pushViewController(PRPackageDetailsViewController(package: package), animated: true)
    }
}
