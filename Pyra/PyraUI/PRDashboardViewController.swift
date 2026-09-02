//  Created by Fauxly on 06.07.2026.


import UIKit

class PRDashboardViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {

    /// Один ряд = один репозиторий (заголовок + его пакеты). Для кастомных списков
    /// (категория, отдельный репозиторий из "Источников") — один ряд без заголовка.
    private struct Row {
        let title: String
        let packages: [PRPackage]
    }

    private var collectionView: UICollectionView!
    private var rows: [Row] = []

    // Если true — контроллер показывает список, переданный извне через setCustomPackages(_:),
    // и не должен сам запускать автозагрузку по репозиториям через loadData().
    private var usesCustomPackages = false
    private var pendingRows: [Row]?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = PRTheme.ink
        
        setupCollectionView()
        
        if let pending = pendingRows {
            rows = pending
            pendingRows = nil
            collectionView.reloadData()
        } else if !usesCustomPackages && PRAppSettings.autoUpdateOnLaunch {
            loadData()
        }
    }
    
    private func setupCollectionView() {
        let layout = createLayout()
        
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = .clear
        
        collectionView.register(PRPackageCell.self, forCellWithReuseIdentifier: PRPackageCell.reuseIdentifier)
        collectionView.register(
            PRSectionHeaderView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: PRSectionHeaderView.reuseIdentifier
        )
        
        collectionView.dataSource = self
        collectionView.delegate = self
        
        // Запоминаем фокус при навигации на tvOS
        collectionView.remembersLastFocusedIndexPath = true
        
        view.addSubview(collectionView)
    }
    
    private func createLayout() -> UICollectionViewLayout {
        // sectionProvider, а не статичная секция — количество рядов теперь динамическое
        // (по числу репозиториев), и у каждого ряда либо есть заголовок, либо нет.
        UICollectionViewCompositionalLayout { [weak self] sectionIndex, _ in
            guard let self, sectionIndex < self.rows.count else { return nil }
            
            // 5 плиток в один ряд (ширина 0.2 от экрана)
            let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.2),
                                                  heightDimension: .fractionalHeight(1.0))
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            item.contentInsets = NSDirectionalEdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20)
            
            let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                                   heightDimension: .absolute(300))
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
            
            let section = NSCollectionLayoutSection(group: group)
            // Горизонтальный скролл внутри ряда; переход МЕЖДУ рядами (вверх/вниз) даёт
            // сам Focus Engine из коробки, раз секции просто стоят одна под другой.
            section.orthogonalScrollingBehavior = .continuous
            
            let title = self.rows[sectionIndex].title
            if !title.isEmpty {
                let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                                         heightDimension: .absolute(70))
                let header = NSCollectionLayoutBoundarySupplementaryItem(
                    layoutSize: headerSize,
                    elementKind: UICollectionView.elementKindSectionHeader,
                    alignment: .top
                )
                section.boundarySupplementaryItems = [header]
            }
            
            return section
        }
    }
    
    private func loadData() {
        Task {
            let repositories = PRRepositoryManager.shared.repositories
            
            // Тянем пакеты каждого репозитория параллельно, но собираем обратно
            // в исходном порядке репозиториев, а не в порядке завершения запросов.
            let fetchedRows = await withTaskGroup(of: (Int, Row).self) { group in
                for (index, repository) in repositories.enumerated() {
                    group.addTask {
                        let packages = (try? await PRNetworkManager.shared.fetchPackages(from: repository)) ?? []
                        return (index, Row(title: repository.name, packages: packages))
                    }
                }
                
                var results: [(Int, Row)] = []
                for await result in group {
                    results.append(result)
                }
                return results.sorted { $0.0 < $1.0 }.map { $0.1 }
            }
            
            await MainActor.run {
                // Скрываем ряды без пакетов (репозиторий недоступен/пуст) — пустой
                // горизонтальный ряд без единой плитки выглядел бы как баг, а не фича.
                self.rows = fetchedRows.filter { !$0.packages.isEmpty }
                self.collectionView.reloadData()
            }
        }
    }
    
    /// Показывает заранее подготовленный список пакетов одним рядом без заголовка —
    /// например, отфильтрованный по категории (PRCategoriesViewController) или пакеты
    /// одного конкретного репозитория (PRRepositoriesViewController) — вместо автоматической
    /// подгрузки по всем репозиториям через loadData().
    func setCustomPackages(_ packages: [PRPackage]) {
        usesCustomPackages = true
        let newRows = [Row(title: "", packages: packages)]
        
        guard isViewLoaded, collectionView != nil else {
            pendingRows = newRows
            return
        }
        
        rows = newRows
        collectionView.reloadData()
    }
    
    /// Форс-перезагрузка — например, после того как пользователь добавил или удалил
    /// репозиторий. Не действует, если экран сейчас показывает кастомный список.
    func refresh() {
        guard !usesCustomPackages, isViewLoaded else { return }
        loadData()
    }
    
    // MARK: - UICollectionViewDataSource
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        rows.count
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        rows[section].packages.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PRPackageCell.reuseIdentifier, for: indexPath) as? PRPackageCell else {
            return UICollectionViewCell()
        }
        
        let package = rows[indexPath.section].packages[indexPath.item]
        cell.configure(with: package)
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        guard kind == UICollectionView.elementKindSectionHeader,
              let header = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind,
                withReuseIdentifier: PRSectionHeaderView.reuseIdentifier,
                for: indexPath
              ) as? PRSectionHeaderView else {
            return UICollectionReusableView()
        }
        
        header.configure(title: rows[indexPath.section].title)
        return header
    }
    
    // MARK: - UICollectionViewDelegate
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let package = rows[indexPath.section].packages[indexPath.item]
        let detailsVC = PRPackageDetailsViewController(package: package)
        navigationController?.pushViewController(detailsVC, animated: true)
    }
}
