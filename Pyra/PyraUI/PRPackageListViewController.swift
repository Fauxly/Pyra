//
//  PRPackageListViewController.swift
//  Pyra
//  Created by Fauxly on 27.09.2026.

import UIKit

/// Экран раздела: все пакеты одной категории или одного репозитория.
/// Сверху шапка в цвет раздела (иконка, название, число пакетов), ниже — сетка плиток
/// по 5 в ряд, сгруппированная: внутри репозитория — по категориям, внутри категории —
/// по источникам. Пока пакеты грузятся — скелетоны.
final class PRPackageListViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {

    enum Mode {
        case category(name: String)
        case repository(PRRepository)
    }

    private struct Group {
        let title: String
        let iconURL: URL?
        let packages: [PRPackage]
    }

    private let mode: Mode
    private var groups: [Group] = []
    private var isLoading = false
    private var collectionView: UICollectionView!

    private let headerView = UIView()
    private let glowView = PRGradientView()
    private let iconBadge = UIView()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let emptyLabel = UILabel()
    private var iconTask: Task<Void, Never>?

    init(mode: Mode) {
        self.mode = mode
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) не поддерживается")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = PRTheme.ink
        setupHeader()
        setupCollectionView()
        setupEmptyLabel()
        // Данные могли прийти до загрузки view (категория передаёт пакеты сразу) —
        // reload() покажет либо их, либо скелетоны, если идёт загрузка
        reload()
    }

    // MARK: - Данные

    /// Показать скелетоны, пока пакеты грузятся (репозиторий тянется из сети)
    func showLoading() {
        isLoading = true
        groups = []
        if isViewLoaded { reload() }
    }

    func setPackages(_ packages: [PRPackage]) {
        isLoading = false
        groups = makeGroups(from: packages)
        if isViewLoaded { reload() }
    }

    private func reload() {
        let total = groups.reduce(0) { $0 + $1.packages.count }
        configureHeader(packageCount: isLoading ? nil : total)
        emptyLabel.isHidden = isLoading || total > 0
        collectionView.reloadData()
    }

    private func makeGroups(from packages: [PRPackage]) -> [Group] {
        func byName(_ a: PRPackage, _ b: PRPackage) -> Bool {
            a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }

        switch mode {
        case .repository:
            // Внутри репозитория — по категориям, самые наполненные сверху
            let grouped = Dictionary(grouping: packages) { package -> String in
                let section = package.section.trimmingCharacters(in: .whitespaces)
                return section.isEmpty || section.lowercased() == "unknown" ? "PACKAGE_LIST_OTHER".localized : section
            }
            return grouped
                .map { Group(title: $0.key, iconURL: nil, packages: $0.value.sorted(by: byName)) }
                .sorted { $0.packages.count != $1.packages.count ? $0.packages.count > $1.packages.count : $0.title < $1.title }

        case .category:
            // Внутри категории — по источникам, с иконкой репозитория в заголовке
            let grouped = Dictionary(grouping: packages) { $0.sourceRepository?.id }
            return grouped
                .map { _, items in
                    let repository = items.first?.sourceRepository
                    return Group(title: repository?.name ?? "PACKAGE_LIST_OTHER".localized,
                                 iconURL: repository?.iconURL,
                                 packages: items.sorted(by: byName))
                }
                .sorted { $0.packages.count != $1.packages.count ? $0.packages.count > $1.packages.count : $0.title < $1.title }
        }
    }

    // MARK: - Шапка

    private func setupHeader() {
        headerView.backgroundColor = PRTheme.surface
        headerView.layer.cornerRadius = 30
        headerView.layer.cornerCurve = .continuous
        headerView.clipsToBounds = true
        headerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerView)

        glowView.gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        glowView.gradientLayer.endPoint = CGPoint(x: 0.8, y: 0.5)
        glowView.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(glowView)

        iconBadge.layer.cornerRadius = 28
        iconBadge.layer.cornerCurve = .continuous
        iconBadge.clipsToBounds = true
        iconBadge.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(iconBadge)

        iconView.contentMode = .center
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 50, weight: .semibold)
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconBadge.addSubview(iconView)

        titleLabel.font = UIFont.systemFont(ofSize: 54, weight: .heavy)
        titleLabel.textColor = PRTheme.textPrimary
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.6
        subtitleLabel.font = UIFont.systemFont(ofSize: 26, weight: .medium)
        subtitleLabel.textColor = PRTheme.textSecondary

        let textStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        textStack.axis = .vertical
        textStack.spacing = 4
        textStack.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(textStack)

        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.topAnchor, constant: 24),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: PRGridLayout.horizontalInset),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -PRGridLayout.horizontalInset),
            headerView.heightAnchor.constraint(equalToConstant: 170),

            glowView.topAnchor.constraint(equalTo: headerView.topAnchor),
            glowView.bottomAnchor.constraint(equalTo: headerView.bottomAnchor),
            glowView.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            glowView.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),

            iconBadge.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 36),
            iconBadge.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            iconBadge.widthAnchor.constraint(equalToConstant: 112),
            iconBadge.heightAnchor.constraint(equalToConstant: 112),
            iconView.topAnchor.constraint(equalTo: iconBadge.topAnchor),
            iconView.bottomAnchor.constraint(equalTo: iconBadge.bottomAnchor),
            iconView.leadingAnchor.constraint(equalTo: iconBadge.leadingAnchor),
            iconView.trailingAnchor.constraint(equalTo: iconBadge.trailingAnchor),

            textStack.leadingAnchor.constraint(equalTo: iconBadge.trailingAnchor, constant: 34),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: headerView.trailingAnchor, constant: -40),
            textStack.centerYAnchor.constraint(equalTo: headerView.centerYAnchor)
        ])

        // Внешний вид шапки зависит от раздела, а не от данных — настраиваем один раз
        switch mode {
        case .category(let name):
            let style = PRCategoryStyle.style(for: name)
            titleLabel.text = name
            glowView.gradientLayer.colors = [style.color.withAlphaComponent(0.35).cgColor, style.color.withAlphaComponent(0).cgColor]
            iconBadge.backgroundColor = style.color.withAlphaComponent(0.22)
            iconView.image = UIImage(systemName: style.symbol)
            iconView.tintColor = style.color

        case .repository(let repository):
            titleLabel.text = repository.name
            glowView.gradientLayer.colors = [PRTheme.brass.withAlphaComponent(0.3).cgColor, PRTheme.brass.withAlphaComponent(0).cgColor]
            iconBadge.backgroundColor = PRTheme.surfaceFocused
            iconView.image = UIImage(systemName: "shippingbox")
            iconView.tintColor = PRTheme.textSecondary
            iconTask = Task { [weak self] in
                guard let image = await PRImageCache.shared.image(for: repository.iconURL.absoluteString) else { return }
                await MainActor.run {
                    self?.iconView.contentMode = .scaleAspectFill
                    self?.iconView.image = image
                }
            }
        }
    }

    private func configureHeader(packageCount: Int?) {
        var parts: [String] = []
        if let packageCount {
            parts.append(String(format: "CATEGORIES_PACKAGE_COUNT".localized, packageCount))
        } else {
            parts.append("SOURCES_STATUS_LOADING".localized)
        }
        switch mode {
        case .category:
            if !groups.isEmpty {
                parts.append(String(format: "PACKAGE_LIST_SOURCES_COUNT".localized, groups.count))
            }
        case .repository(let repository):
            parts.append(repository.baseURL.host ?? repository.baseURL.absoluteString)
        }
        subtitleLabel.text = parts.joined(separator: "  ·  ")
    }

    // MARK: - Сетка

    private func setupCollectionView() {
        let layout = UICollectionViewCompositionalLayout { [weak self] _, _ in
            let hasHeaders = !(self?.isLoading ?? true)
            return PRGridLayout.section(columns: 5, itemHeight: 260, spacing: 30, header: hasHeaders, topInset: 10)
        }
        collectionView = PRGridLayout.makeCollectionView(in: view, layout: layout)
        collectionView.register(PRPackageCell.self, forCellWithReuseIdentifier: PRPackageCell.reuseIdentifier)
        collectionView.register(PRSkeletonCell.self, forCellWithReuseIdentifier: PRSkeletonCell.reuseIdentifier)
        collectionView.register(PRSectionHeaderView.self,
                                forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
                                withReuseIdentifier: PRSectionHeaderView.reuseIdentifier)
        collectionView.dataSource = self
        collectionView.delegate = self

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 12),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    private func setupEmptyLabel() {
        emptyLabel.text = "PACKAGE_LIST_EMPTY".localized
        emptyLabel.font = UIFont.systemFont(ofSize: 32, weight: .bold)
        emptyLabel.textColor = PRTheme.textSecondary
        emptyLabel.isHidden = true
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyLabel)
        NSLayoutConstraint.activate([
            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: collectionView.centerYAnchor)
        ])
    }

    // MARK: - UICollectionViewDataSource

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        isLoading ? 1 : groups.count
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        isLoading ? 10 : groups[section].packages.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if isLoading {
            return collectionView.dequeueReusableCell(withReuseIdentifier: PRSkeletonCell.reuseIdentifier, for: indexPath)
        }
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PRPackageCell.reuseIdentifier, for: indexPath) as? PRPackageCell else {
            return UICollectionViewCell()
        }
        cell.configure(with: groups[indexPath.section].packages[indexPath.item])
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        guard !isLoading,
              let header = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind, withReuseIdentifier: PRSectionHeaderView.reuseIdentifier, for: indexPath
              ) as? PRSectionHeaderView else {
            return UICollectionReusableView()
        }
        let group = groups[indexPath.section]
        header.leadingInset = PRGridLayout.horizontalInset
        header.configure(title: "\(group.title)  ·  \(group.packages.count)", iconURL: group.iconURL)
        return header
    }

    // MARK: - UICollectionViewDelegate

    func collectionView(_ collectionView: UICollectionView, canFocusItemAt indexPath: IndexPath) -> Bool {
        !isLoading
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard !isLoading else { return }
        let package = groups[indexPath.section].packages[indexPath.item]
        navigationController?.pushViewController(PRPackageDetailsViewController(package: package), animated: true)
    }
}
