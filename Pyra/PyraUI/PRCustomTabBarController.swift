//
//  PRCustomTabBarController.swift
//  Pyra
//  Created by Fauxly on 06.07.2026.

import UIKit

/// Полностью самодельная замена UITabBarController. Системный UITabBar не даёт вставлять
/// в свою строку произвольные элементы (там только UITabBarItem на каждый viewController),
/// поэтому единственный способ получить кнопку "Назад" РЯДОМ со вкладками, а не под/над
/// системным баром — отказаться от системного бара целиком и нарисовать свой.
public final class PRCustomTabBarController: UIViewController {

    private struct Tab {
        let title: String
        let icon: String
        let navController: UINavigationController
    }

    private let topBar = UIView()
    private let backButton = PRTabBarButton()
    private let contentContainer = UIView()

    private var tabs: [Tab] = []
    private var tabButtons: [PRTabItemButton] = []

    // Полный каталог — нужен, чтобы открыть пакет по ссылке pyra://package/<id>
    // (с верхней полки домашнего экрана). Если ссылка пришла раньше каталога — ждём его.
    private var allPackages: [PRPackage] = []
    private var pendingPackageID: String?
    private var isCatalogLoading = false

    // Первая вкладка крепится либо к кнопке "Назад", либо (когда та скрыта) прямо к краю
    // бара — иначе невидимая кнопка оставляла бы пустую дыру слева и бар выглядел кривым
    private var firstTabAfterBackConstraint: NSLayoutConstraint?
    private var firstTabAtEdgeConstraint: NSLayoutConstraint?

    /// Индекс вкладки "Обновления" — на её кнопке висит бейдж с числом доступных апдейтов
    private let updatesTabIndex = 5

    private var selectedIndex: Int = 0 {
        didSet { updateSelectedTab() }
    }

    // Держим ссылки на конкретные экраны — нужны для loadCatalog(), как раньше в PRMainTabBarController
    private weak var dashboardVC: PRDashboardViewController?
    private weak var categoriesVC: PRCategoriesViewController?
    private weak var searchVC: PRSearchViewController?
    private weak var installedVC: PRInstalledViewController?
    private weak var updatesVC: PRUpdatesViewController?
    private weak var repositoriesVC: PRRepositoriesViewController?

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = PRTheme.ink

        setupTabs()
        setupTopBar()
        setupContent()

        selectedIndex = 0
        // Автозагрузку при старте можно отключить в настройках — тогда каталог для категорий/
        // поиска не тянется сразу, но остаётся доступным по кнопке "обновить" в Источниках
        // (это явное действие пользователя, оно не подчиняется этому переключателю).
        if PRAppSettings.autoUpdateOnLaunch {
            loadCatalog()
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(repositoriesDidChange),
            name: PRRepositoryManager.repositoriesDidChangeNotification,
            object: nil
        )
    }

    // MARK: - Вкладки

    private func setupTabs() {
        let dashboardVC = PRDashboardViewController()
        let categoriesVC = PRCategoriesViewController()
        let repoVC = PRRepositoriesViewController()
        let searchVC = PRSearchViewController()
        let installedVC = PRInstalledViewController()
        let updatesVC = PRUpdatesViewController()
        let settingsVC = PRSettingsViewController()

        self.dashboardVC = dashboardVC
        self.categoriesVC = categoriesVC
        self.searchVC = searchVC
        self.installedVC = installedVC
        self.updatesVC = updatesVC
        self.repositoriesVC = repoVC

        // Бейдж на вкладке "Обновления": экран сам пересчитывает список при каждом новом
        // каталоге и при заходе на вкладку — просто зеркалим это число на кнопку бара
        updatesVC.onUpdatesCountChange = { [weak self] count in
            guard let self, self.updatesTabIndex < self.tabButtons.count else { return }
            self.tabButtons[self.updatesTabIndex].badgeCount = count
        }

        // Явная аннотация типа обязательна: без неё компилятор не может вывести тип массива
        // из 6 разных подклассов UIViewController одним выражением с .map (Swift type checker
        // сдаётся на такой комбинации — "ambiguous without type annotation").
        let rootViewControllers: [UIViewController] = [dashboardVC, categoriesVC, repoVC, searchVC, installedVC, updatesVC, settingsVC]
        let navControllers: [UINavigationController] = rootViewControllers.map { (vc: UIViewController) -> UINavigationController in
            let nav = UINavigationController(rootViewController: vc)
            nav.setNavigationBarHidden(true, animated: false)
            nav.delegate = self
            return nav
        }

        tabs = [
            Tab(title: "TAB_MAIN".localized, icon: "house", navController: navControllers[0]),
            Tab(title: "TAB_CATEGORIES".localized, icon: "square.grid.2x2", navController: navControllers[1]),
            Tab(title: "TAB_SOURCES".localized, icon: "tray.2", navController: navControllers[2]),
            Tab(title: "TAB_SEARCH".localized, icon: "magnifyingglass", navController: navControllers[3]),
            Tab(title: "TAB_INSTALLED".localized, icon: "checkmark.circle", navController: navControllers[4]),
            Tab(title: "TAB_UPDATES".localized, icon: "arrow.down.circle", navController: navControllers[5]),
            Tab(title: "TAB_SETTINGS".localized, icon: "gearshape", navController: navControllers[6])
        ]
    }

    // MARK: - Верхняя панель (свой таб-бар + кнопка "Назад" в одном ряду)

    private func setupTopBar() {
        // Стеклянная полоса (вариант C): иконка над подписью у каждой вкладки, активная
        // подсвечена латунью на светлой подложке. Скругление меньше, чем у "таблетки" —
        // бар стал выше из-за двухстрочных кнопок, полная капсула смотрелась бы как пузырь.
        topBar.backgroundColor = PRTheme.surface.withAlphaComponent(0.96)
        topBar.layer.cornerRadius = 30
        topBar.layer.cornerCurve = .continuous
        topBar.layer.borderWidth = 1
        topBar.layer.borderColor = UIColor.white.withAlphaComponent(0.08).cgColor
        topBar.layer.shadowColor = UIColor.black.cgColor
        topBar.layer.shadowOpacity = 0.35
        topBar.layer.shadowRadius = 20
        topBar.layer.shadowOffset = CGSize(width: 0, height: 8)
        topBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(topBar)

        NSLayoutConstraint.activate([
            topBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            topBar.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            topBar.heightAnchor.constraint(equalToConstant: 104)
        ])

        // Кнопка "Назад" — первая слева в том же ряду, что и вкладки. Видна только когда
        // в активной вкладке реально есть куда возвращаться (стек навигации глубже корня).
        backButton.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        backButton.setTitle(" " + "COMMON_BACK".localized, for: .normal)
        backButton.isSelectedTab = true // всегда в виде заметной "таблетки", это не индикатор текущей вкладки
        backButton.isHidden = true
        backButton.addTarget(self, action: #selector(backTapped), for: .primaryActionTriggered)
        backButton.translatesAutoresizingMaskIntoConstraints = false
        topBar.addSubview(backButton)

        NSLayoutConstraint.activate([
            backButton.leadingAnchor.constraint(equalTo: topBar.leadingAnchor, constant: 24),
            backButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            backButton.heightAnchor.constraint(equalToConstant: 56)
        ])

        var previousTrailingAnchor = backButton.trailingAnchor
        let previousGap: CGFloat = 6

        for (index, tab) in tabs.enumerated() {
            let button = PRTabItemButton(title: tab.title, systemImage: tab.icon)
            button.tag = index
            // addTarget не нужен — вкладки переключаются автоматически при наведении
            // фокуса (didUpdateFocus), как системный UITabBarController, без нажатия Select.
            button.translatesAutoresizingMaskIntoConstraints = false
            topBar.addSubview(button)

            if index == 0 {
                firstTabAfterBackConstraint = button.leadingAnchor.constraint(equalTo: backButton.trailingAnchor, constant: 24)
                firstTabAtEdgeConstraint = button.leadingAnchor.constraint(equalTo: topBar.leadingAnchor, constant: 16)
                firstTabAtEdgeConstraint?.isActive = true
            } else {
                button.leadingAnchor.constraint(equalTo: previousTrailingAnchor, constant: previousGap).isActive = true
            }

            NSLayoutConstraint.activate([
                button.topAnchor.constraint(equalTo: topBar.topAnchor, constant: 8),
                button.bottomAnchor.constraint(equalTo: topBar.bottomAnchor, constant: -8)
            ])

            tabButtons.append(button)
            previousTrailingAnchor = button.trailingAnchor
        }

        // Правый край бара определяется последней кнопкой — иначе ширина плавающей
        // таблетки (trailingAnchor через lessThanOrEqualTo) осталась бы неопределённой
        if let lastButton = tabButtons.last {
            NSLayoutConstraint.activate([
                topBar.trailingAnchor.constraint(equalTo: lastButton.trailingAnchor, constant: 16)
            ])
        }
    }

    // MARK: - Контент вкладок

    private func setupContent() {
        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(contentContainer)

        NSLayoutConstraint.activate([
            contentContainer.topAnchor.constraint(equalTo: topBar.bottomAnchor, constant: 12),
            contentContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        for tab in tabs {
            addChild(tab.navController)
            tab.navController.view.translatesAutoresizingMaskIntoConstraints = false
            contentContainer.addSubview(tab.navController.view)

            NSLayoutConstraint.activate([
                tab.navController.view.topAnchor.constraint(equalTo: contentContainer.topAnchor),
                tab.navController.view.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
                tab.navController.view.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
                tab.navController.view.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor)
            ])

            tab.navController.didMove(toParent: self)
            tab.navController.view.isHidden = true
        }
    }

    // MARK: - Действия

    // Автоматическое переключение вкладки при наведении фокуса на её кнопку —
    // как системный UITabBarController, без необходимости нажимать Select.
    // Контент переключается плавно через coordinator, синхронно с анимацией фокуса.
    //
    // Блокируется, если текущая вкладка показывает НЕ корневой экран (например, карточку
    // пакета после push) — иначе при листании вниз внутри карточки фокус случайно
    // "зацепляет" кнопку соседней вкладки и выкидывает на неё, теряя текущий контекст.
    public override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        
        guard let nextView = context.nextFocusedView else { return }
        
        // Если мы глубже корня навигации — не переключаем вкладки автоматически
        if tabs[selectedIndex].navController.viewControllers.count > 1 { return }
        
        if let index = tabButtons.firstIndex(where: { $0 === nextView }), index != selectedIndex {
            coordinator.addCoordinatedAnimations({
                self.selectedIndex = index
            }, completion: nil)
        }
    }

    @objc private func backTapped() {
        tabs[selectedIndex].navController.popViewController(animated: true)
    }

    private func updateSelectedTab() {
        for (index, tab) in tabs.enumerated() {
            tab.navController.view.isHidden = index != selectedIndex
        }
        for (index, button) in tabButtons.enumerated() {
            button.isSelectedTab = index == selectedIndex
        }
        updateBackButtonVisibility()
    }

    private func updateBackButtonVisibility() {
        let hidden = tabs[selectedIndex].navController.viewControllers.count <= 1
        guard hidden != backButton.isHidden || firstTabAtEdgeConstraint?.isActive != hidden else { return }

        backButton.isHidden = hidden
        // Сначала выключаем, потом включаем — чтобы в моменте не было двух активных
        // конфликтующих констрейнтов на leading первой вкладки
        if hidden {
            firstTabAfterBackConstraint?.isActive = false
            firstTabAtEdgeConstraint?.isActive = true
        } else {
            firstTabAtEdgeConstraint?.isActive = false
            firstTabAfterBackConstraint?.isActive = true
        }
        UIView.animate(withDuration: 0.25) {
            self.view.layoutIfNeeded()
        }
    }

    // MARK: - Каталог (перенесено из старого PRMainTabBarController)

    private func loadCatalog() {
        isCatalogLoading = true
        Task {
            let packages = await PRRepositoryManager.shared.loadAllPackages()
            // Свежий снимок dpkg status к новому каталогу — значки "установлен/обновление"
            // на плитках и бейдж вкладки считаются от него
            PRInstalledState.shared.refresh()
            await MainActor.run {
                self.isCatalogLoading = false
                self.allPackages = packages
                self.categoriesVC?.allPackages = packages
                self.searchVC?.allPackages = packages
                self.installedVC?.allPackages = packages
                self.updatesVC?.allPackages = packages
                self.repositoriesVC?.allPackages = packages

                if let pending = self.pendingPackageID {
                    self.openPackage(withID: pending)
                }
            }
        }
    }

    // MARK: - Диплинки

    /// Открыть карточку пакета на вкладке "Главная" — вызывается из SceneDelegate
    /// по ссылке pyra://package/<id>
    func openPackage(withID packageID: String) {
        let matches = allPackages.filter { $0.packageID.lowercased() == packageID.lowercased() }
        // Если пакет лежит в нескольких репозиториях/версиях — берём самую новую
        let package = matches.reduce(nil as PRPackage?) { best, candidate in
            guard let best else { return candidate }
            return PRDependencyChecker.compareVersions(candidate.version, ">>", best.version) ? candidate : best
        }

        guard let package else {
            pendingPackageID = packageID
            // Каталог может быть не загружен вовсе (автозагрузка выключена в настройках)
            if allPackages.isEmpty && !isCatalogLoading {
                loadCatalog()
            }
            return
        }

        pendingPackageID = nil
        selectedIndex = 0
        let nav = tabs[0].navController
        nav.popToRootViewController(animated: false)
        nav.pushViewController(PRPackageDetailsViewController(package: package), animated: false)
        updateBackButtonVisibility()
    }

    @objc private func repositoriesDidChange() {
        dashboardVC?.refresh()
        loadCatalog()
    }
    
    // MARK: - Перехват Menu на пульте
    
    // Куда нужно принудительно увести фокус — используется через preferredFocusEnvironments
    private var forcedFocusTarget: UIView?
    
    public override var preferredFocusEnvironments: [UIFocusEnvironment] {
        if let target = forcedFocusTarget {
            return [target]
        }
        return super.preferredFocusEnvironments
    }
    
    // Menu на корне любой вкладки по умолчанию выходит из приложения (стандартное поведение
    // tvOS) — вместо этого перехватываем его здесь, на уровне всего контейнера, и:
    // если в активной вкладке есть куда возвращаться — делаем pop, если уже в корне —
    // просто уводим фокус обратно на бар вкладок, не давая системе выйти из приложения.
    public override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        guard presses.contains(where: { $0.type == .menu }) else {
            super.pressesEnded(presses, with: event)
            return
        }
        
        if isAnyPresentingModal() {
            super.pressesEnded(presses, with: event)
            return
        }
        
        let activeNav = tabs[selectedIndex].navController
        
        if activeNav.viewControllers.count > 1 {
            activeNav.popViewController(animated: true)
            return
        }
        
        forcedFocusTarget = tabButtons[selectedIndex]
        setNeedsFocusUpdate()
        updateFocusIfNeeded()
        // Сбрасываем сразу после — иначе preferredFocusEnvironments будет постоянно
        // "тянуть" фокус назад на кнопку вкладки при каждом обновлении фокуса
        forcedFocusTarget = nil
    }
    
    /// Проверяет, показано ли что-то модально ГДЕ УГОДНО в дереве (алерт с текстовым полем,
    /// системная клавиатура и т.п.) — не только на самом PRCustomTabBarController, но и на
    /// вложенных UINavigationController/их корневых экранах, откуда реально вызывается present(...).
    private func isAnyPresentingModal() -> Bool {
        if presentedViewController != nil { return true }
        return tabs.contains { $0.navController.presentedViewController != nil }
    }
}

// MARK: - UINavigationControllerDelegate

extension PRCustomTabBarController: UINavigationControllerDelegate {
    public func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
        // Срабатывает на каждый push/pop в любой из вкладок — обновляем видимость кнопки
        // "Назад" по факту (не только при переключении вкладок).
        updateBackButtonVisibility()
    }
}
