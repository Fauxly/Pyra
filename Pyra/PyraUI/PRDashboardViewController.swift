//  Created by Fauxly on 06.07.2026.


import UIKit

class PRDashboardViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {

    /// Один ряд = один репозиторий (заголовок + его пакеты). Для кастомных списков
    /// (категория, отдельный репозиторий из "Источников") — один ряд без заголовка.
    private struct Row {
        let title: String
        let iconURL: URL?
        /// Пакеты, показанные в самом ряду (для больших репозиториев — только первые N)
        let packages: [PRPackage]
        /// Репозиторий ряда — для плитки "Все N →"; nil у кастомных списков
        var repository: PRRepository? = nil
        /// Все пакеты репозитория — их открывает плитка "Все N →"
        var allPackages: [PRPackage] = []

        var showsSeeAll: Bool { repository != nil && allPackages.count > packages.count }
    }

    private struct CategoryChip {
        let name: String
        let packages: [PRPackage]
    }

    /// Что стоит в каждой секции коллекции. Держим явный список, а не арифметику
    /// индексов — секций несколько видов, и часть из них появляется/исчезает по состоянию.
    private enum SectionKind {
        case hero
        case fresh
        case categories
        case row(Int)
        case skeletonHero
        case skeletonRow
    }

    /// Сколько пакетов максимум показывать в верхней hero-карусели
    private static let heroLimit = 6
    /// Сколько пакетов показывать в ряду репозитория — остальное за плиткой "Все N →"
    private static let rowLimit = 12
    /// Сколько категорий в полке-таблетках
    private static let categoryChipsLimit = 14
    /// Пауза между автоперелистываниями витрины
    private static let heroAutoScrollInterval: TimeInterval = 7

    private var collectionView: UICollectionView!
    private var rows: [Row] = []
    private var sections: [SectionKind] = []
    private var freshPackages: [PRPackage] = []
    private var categoryChips: [CategoryChip] = []

    /// Пакеты для верхней "витрины" в стиле приложения Apple TV. Пусто — витрины нет
    /// (кастомный список или ещё ничего не загружено).
    private var heroPackages: [PRPackage] = []

    // Если true — контроллер показывает список, переданный извне через setCustomPackages(_:),
    // и не должен сам запускать автозагрузку по репозиториям через loadData().
    private var usesCustomPackages = false
    private var pendingRows: [Row]?

    /// Идёт загрузка каталога, а показать ещё нечего — рисуем скелетоны
    private var isLoading = false

    // Автопрокрутка витрины: крутим, только пока фокус НЕ на ней (как в приложении TV —
    // пока пользователь смотрит на баннер, он не должен уезжать из-под пульта)
    private var heroTimer: Timer?
    private var currentHeroIndex = 0
    private var isHeroFocused = false

    private var showsHero: Bool {
        !usesCustomPackages && !heroPackages.isEmpty
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = PRTheme.ink
        
        setupCollectionView()
        
        if let pending = pendingRows {
            rows = pending
            pendingRows = nil
            reloadSections()
        } else if !usesCustomPackages && PRAppSettings.autoUpdateOnLaunch {
            loadData()
        }
    }

    deinit {
        heroTimer?.invalidate()
    }
    
    private func setupCollectionView() {
        let layout = createLayout()
        
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = .clear
        
        collectionView.register(PRHeroCell.self, forCellWithReuseIdentifier: PRHeroCell.reuseIdentifier)
        collectionView.register(PRPackageCell.self, forCellWithReuseIdentifier: PRPackageCell.reuseIdentifier)
        collectionView.register(PRSkeletonCell.self, forCellWithReuseIdentifier: PRSkeletonCell.reuseIdentifier)
        collectionView.register(PRWideCardCell.self, forCellWithReuseIdentifier: PRWideCardCell.reuseIdentifier)
        collectionView.register(PRCategoryChipCell.self, forCellWithReuseIdentifier: PRCategoryChipCell.reuseIdentifier)
        collectionView.register(PRSeeAllCell.self, forCellWithReuseIdentifier: PRSeeAllCell.reuseIdentifier)
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

    /// Пересобрать список секций по текущему состоянию и перерисовать коллекцию
    private func reloadSections() {
        if isLoading && rows.isEmpty && !usesCustomPackages {
            sections = [.skeletonHero, .skeletonRow, .skeletonRow]
        } else {
            var built: [SectionKind] = showsHero ? [.hero] : []
            if !usesCustomPackages && !freshPackages.isEmpty { built.append(.fresh) }
            if !usesCustomPackages && !categoryChips.isEmpty { built.append(.categories) }
            built += rows.indices.map { SectionKind.row($0) }
            sections = built
        }
        currentHeroIndex = 0
        collectionView.reloadData()
        updateHeroTimer()
    }
    
    // MARK: - Layout

    private func createLayout() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout { [weak self] sectionIndex, _ in
            guard let self, sectionIndex < self.sections.count else { return nil }

            switch self.sections[sectionIndex] {
            case .hero:
                return self.createHeroSection(tracksCurrentItem: true)
            case .skeletonHero:
                return self.createHeroSection(tracksCurrentItem: false)
            case .fresh:
                return self.createFreshSection()
            case .categories:
                return self.createCategoriesSection()
            case .row(let index):
                return self.createRowSection(withHeader: !self.rows[index].title.isEmpty)
            case .skeletonRow:
                return self.createRowSection(withHeader: false)
            }
        }
    }

    private func createRowSection(withHeader: Bool) -> NSCollectionLayoutSection {
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
        
        if withHeader {
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

    private func makeHeaderItem() -> NSCollectionLayoutBoundarySupplementaryItem {
        NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(70)),
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top
        )
    }

    /// "Новое и обновлённое" — широкие карточки с описанием, листаются вбок
    private func createFreshSection() -> NSCollectionLayoutSection {
        let size = NSCollectionLayoutSize(widthDimension: .absolute(640), heightDimension: .absolute(180))
        let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(1)))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: size, subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .continuous
        section.interGroupSpacing = 30
        section.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 40, bottom: 34, trailing: 40)
        section.boundarySupplementaryItems = [makeHeaderItem()]
        return section
    }

    /// "Категории" — цветные таблетки, ширина по содержимому
    private func createCategoriesSection() -> NSCollectionLayoutSection {
        let size = NSCollectionLayoutSize(widthDimension: .estimated(260), heightDimension: .absolute(80))
        let item = NSCollectionLayoutItem(layoutSize: size)
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: size, subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .continuous
        section.interGroupSpacing = 22
        section.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 40, bottom: 34, trailing: 40)
        section.boundarySupplementaryItems = [makeHeaderItem()]
        return section
    }

    /// Верхняя витрина: широкие баннеры по одному на экран, соседние "выглядывают" по бокам,
    /// листаются постранично с центрированием — как верхняя полка в приложении Apple TV.
    private func createHeroSection(tracksCurrentItem: Bool) -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                              heightDimension: .fractionalHeight(1.0))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.86),
                                               heightDimension: .absolute(520))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .groupPagingCentered
        section.interGroupSpacing = 40
        // Запас сверху/снизу под увеличение карточки в фокусе и её тень
        section.contentInsets = NSDirectionalEdgeInsets(top: 30, leading: 0, bottom: 50, trailing: 0)

        if tracksCurrentItem {
            // Запоминаем, какой баннер сейчас по центру — от него автопрокрутка берёт "следующий",
            // даже если пользователь листал витрину вручную
            section.visibleItemsInvalidationHandler = { [weak self] items, offset, environment in
                let centerX = offset.x + environment.container.contentSize.width / 2
                let closest = items
                    .filter { $0.representedElementCategory == .cell }
                    .min { abs($0.frame.midX - centerX) < abs($1.frame.midX - centerX) }
                if let closest {
                    self?.currentHeroIndex = closest.indexPath.item
                }
            }
        }
        return section
    }

    // MARK: - Данные
    
    private func loadData() {
        isLoading = true
        if rows.isEmpty {
            reloadSections()
        }

        Task {
            let repositories = PRRepositoryManager.shared.repositories
            
            // Тянем пакеты каждого репозитория параллельно, но собираем обратно
            // в исходном порядке репозиториев, а не в порядке завершения запросов.
            let fetchedRows = await withTaskGroup(of: (Int, Row).self) { group in
                for (index, repository) in repositories.enumerated() {
                    group.addTask {
                        let packages = (try? await PRNetworkManager.shared.fetchPackages(from: repository)) ?? []
                        return (index, Row(title: repository.name, iconURL: repository.iconURL, packages: packages,
                                           repository: repository, allPackages: packages))
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
                let repoRows = fetchedRows.filter { !$0.packages.isEmpty }
                let catalog = repoRows.flatMap { $0.allPackages }

                // "Новое и обновлённое" — отдельной полкой широких карточек под витриной
                let fresh = PRFreshTracker.shared.freshPackages(from: catalog)
                self.freshPackages = fresh

                // Полка категорий: самые наполненные сверху
                let byCategory = Dictionary(grouping: catalog) { $0.section.trimmingCharacters(in: .whitespaces) }
                self.categoryChips = byCategory
                    .filter { !$0.key.isEmpty && $0.key.lowercased() != "unknown" }
                    .map { CategoryChip(name: $0.key, packages: $0.value) }
                    .sorted { $0.packages.count > $1.packages.count }
                    .prefix(Self.categoryChipsLimit)
                    .map { $0 }

                // Ряды репозиториев: в самом ряду — первые N пакетов, остальное за "Все N →"
                self.rows = repoRows.map { row in
                    Row(title: row.title, iconURL: row.iconURL,
                        packages: Array(row.allPackages.prefix(Self.rowLimit)),
                        repository: row.repository, allPackages: row.allPackages)
                }
                self.heroPackages = Self.pickFeatured(from: repoRows, limit: Self.heroLimit)
                self.isLoading = false
                self.reloadSections()

                // Та же витрина + "Новое" уходят на верхнюю полку домашнего экрана
                PRTopShelfStore.shared.save(featured: self.heroPackages, fresh: fresh)
            }
        }
    }

    /// Подбор пакетов для витрины: сначала по одному с каждого репозитория (чтобы
    /// витрина не состояла из одного источника), затем добор из остальных. Пакеты с иконкой
    /// в приоритете — баннер без иконки выглядит заметно беднее. Порядок случайный,
    /// так что при каждом обновлении витрина немного меняется.
    private static func pickFeatured(from rows: [Row], limit: Int) -> [PRPackage] {
        func hasIcon(_ package: PRPackage) -> Bool {
            !(package.iconURL ?? "").isEmpty
        }

        var picked: [PRPackage] = []
        var seen = Set<String>()

        for row in rows.shuffled() {
            guard picked.count < limit else { break }
            let withIcon = row.packages.filter(hasIcon)
            if let candidate = withIcon.randomElement() ?? row.packages.randomElement(),
               seen.insert(candidate.packageID).inserted {
                picked.append(candidate)
            }
        }

        let rest = rows.flatMap { $0.packages }
            .filter { hasIcon($0) && !seen.contains($0.packageID) }
            .shuffled()
        for package in rest {
            guard picked.count < limit else { break }
            if seen.insert(package.packageID).inserted {
                picked.append(package)
            }
        }

        return picked
    }
    
    /// Показывает заранее подготовленный список пакетов одним рядом без заголовка —
    /// например, отфильтрованный по категории (PRCategoriesViewController) или пакеты
    /// одного конкретного репозитория (PRRepositoriesViewController) — вместо автоматической
    /// подгрузки по всем репозиториям через loadData(). Витрина в этом режиме не показывается.
    func setCustomPackages(_ packages: [PRPackage]) {
        usesCustomPackages = true
        heroPackages = []
        let newRows = [Row(title: "", iconURL: nil, packages: packages)]
        freshPackages = []
        categoryChips = []
        
        guard isViewLoaded, collectionView != nil else {
            pendingRows = newRows
            return
        }
        
        rows = newRows
        reloadSections()
    }
    
    /// Форс-перезагрузка — например, после того как пользователь добавил или удалил
    /// репозиторий. Не действует, если экран сейчас показывает кастомный список.
    func refresh() {
        guard !usesCustomPackages, isViewLoaded else { return }
        loadData()
    }

    // MARK: - Автопрокрутка витрины

    private func updateHeroTimer() {
        heroTimer?.invalidate()
        heroTimer = nil
        guard showsHero, heroPackages.count > 1 else { return }

        heroTimer = Timer.scheduledTimer(withTimeInterval: Self.heroAutoScrollInterval, repeats: true) { [weak self] _ in
            self?.advanceHero()
        }
    }

    private func advanceHero() {
        guard showsHero,
              heroPackages.count > 1,
              !isHeroFocused,
              isActuallyVisible,
              case .hero? = sections.first else { return }

        let next = (currentHeroIndex + 1) % heroPackages.count
        collectionView.scrollToItem(at: IndexPath(item: next, section: 0), at: .centeredHorizontally, animated: true)
        currentHeroIndex = next
    }

    /// Вкладки переключаются через isHidden у контейнеров, а не через push/present —
    /// поэтому viewWillDisappear тут не срабатывает, и видимость проверяем по цепочке view
    private var isActuallyVisible: Bool {
        guard view.window != nil else { return false }
        var current: UIView? = view
        while let candidate = current {
            if candidate.isHidden { return false }
            current = candidate.superview
        }
        return navigationController?.topViewController === self
    }

    // MARK: - Helpers

    private func package(at indexPath: IndexPath) -> PRPackage? {
        switch sections[indexPath.section] {
        case .hero:
            return heroPackages[indexPath.item]
        case .fresh:
            return freshPackages[indexPath.item]
        case .row(let index):
            let packages = rows[index].packages
            return indexPath.item < packages.count ? packages[indexPath.item] : nil // иначе — плитка "Все"
        case .categories, .skeletonHero, .skeletonRow:
            return nil
        }
    }
    
    // MARK: - UICollectionViewDataSource
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        sections.count
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch sections[section] {
        case .hero: return heroPackages.count
        case .fresh: return freshPackages.count
        case .categories: return categoryChips.count
        case .row(let index): return rows[index].packages.count + (rows[index].showsSeeAll ? 1 : 0)
        case .skeletonHero: return 2
        case .skeletonRow: return 6
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch sections[indexPath.section] {
        case .hero:
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PRHeroCell.reuseIdentifier, for: indexPath) as? PRHeroCell else {
                return UICollectionViewCell()
            }
            cell.configure(with: heroPackages[indexPath.item])
            return cell

        case .fresh:
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PRWideCardCell.reuseIdentifier, for: indexPath) as? PRWideCardCell else {
                return UICollectionViewCell()
            }
            cell.configure(with: freshPackages[indexPath.item])
            return cell

        case .categories:
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PRCategoryChipCell.reuseIdentifier, for: indexPath) as? PRCategoryChipCell else {
                return UICollectionViewCell()
            }
            let chip = categoryChips[indexPath.item]
            cell.configure(name: chip.name, count: chip.packages.count)
            return cell

        case .row(let index):
            let row = rows[index]
            if indexPath.item >= row.packages.count {
                guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PRSeeAllCell.reuseIdentifier, for: indexPath) as? PRSeeAllCell else {
                    return UICollectionViewCell()
                }
                cell.configure(total: row.allPackages.count)
                return cell
            }
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PRPackageCell.reuseIdentifier, for: indexPath) as? PRPackageCell else {
                return UICollectionViewCell()
            }
            cell.configure(with: row.packages[indexPath.item])
            return cell

        case .skeletonHero, .skeletonRow:
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PRSkeletonCell.reuseIdentifier, for: indexPath) as? PRSkeletonCell else {
                return UICollectionViewCell()
            }
            if case .skeletonHero = sections[indexPath.section] {
                cell.configure(cornerRadius: 36)
            }
            return cell
        }
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

        switch sections[indexPath.section] {
        case .fresh:
            header.configure(title: "DASHBOARD_FRESH".localized)
        case .categories:
            header.configure(title: "TAB_CATEGORIES".localized)
        case .row(let index):
            header.configure(title: rows[index].title, iconURL: rows[index].iconURL)
        default:
            header.configure(title: "")
        }
        return header
    }
    
    // MARK: - UICollectionViewDelegate

    func collectionView(_ collectionView: UICollectionView, canFocusItemAt indexPath: IndexPath) -> Bool {
        switch sections[indexPath.section] {
        case .skeletonHero, .skeletonRow: return false
        default: return true
        }
    }

    func collectionView(_ collectionView: UICollectionView, didUpdateFocusIn context: UICollectionViewFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        if let next = context.nextFocusedIndexPath, next.section < sections.count, case .hero = sections[next.section] {
            isHeroFocused = true
            currentHeroIndex = next.item
        } else {
            isHeroFocused = false
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        switch sections[indexPath.section] {
        case .categories:
            let chip = categoryChips[indexPath.item]
            let categoryVC = PRPackageListViewController(mode: .category(name: chip.name))
            categoryVC.setPackages(chip.packages)
            navigationController?.pushViewController(categoryVC, animated: true)
            return

        case .row(let index):
            let row = rows[index]
            if indexPath.item >= row.packages.count, let repository = row.repository {
                let repositoryVC = PRPackageListViewController(mode: .repository(repository))
                repositoryVC.setPackages(row.allPackages)
                navigationController?.pushViewController(repositoryVC, animated: true)
                return
            }

        default:
            break
        }

        guard let package = package(at: indexPath) else { return }
        navigationController?.pushViewController(PRPackageDetailsViewController(package: package), animated: true)
    }
}
