//
//  PRRepositoryManager.swift
//  Pyra
//
//  Created by Fauxly on 06.07.2026.
//

import Foundation

final class PRRepositoryManager {

    static let shared = PRRepositoryManager()

    /// Отправляется всякий раз, когда список репозиториев меняется (добавление/удаление),
    /// чтобы экраны, которые уже загрузили каталог (дашборд, категории, поиск), могли обновиться.
    static let repositoriesDidChangeNotification = Notification.Name("PRRepositoryManager.repositoriesDidChange")

    /// Отправляются вокруг фактической сетевой загрузки каталога — чтобы экраны (например,
    /// список репозиториев) могли показать индикатор загрузки, не завися от того,
    /// кто именно инициировал обновление (добавление репо, кнопка "обновить" и т.д.).
    static let didStartRefreshingNotification = Notification.Name("PRRepositoryManager.didStartRefreshing")
    static let didFinishRefreshingNotification = Notification.Name("PRRepositoryManager.didFinishRefreshing")
    
    /// То же самое, но по КОНКРЕТНОМУ репозиторию — id репозитория лежит в userInfo["repositoryID"].
    /// Нужно, чтобы показать прогресс не общей полосой на весь экран, а отдельно на каждой строке.
    static let repositoryDidStartRefreshingNotification = Notification.Name("PRRepositoryManager.repositoryDidStartRefreshing")
    static let repositoryDidFinishRefreshingNotification = Notification.Name("PRRepositoryManager.repositoryDidFinishRefreshing")

    private let userDefaultsKey = "PRRepositoryManager.repositories"

    private(set) var repositories: [PRRepository] = []

    /// Уведомления слушают экраны UIKit, которые сами дёргают UIKit API (reloadData, анимации)
    /// прямо в обработчике. NotificationCenter доставляет уведомление синхронно на ТОМ ЖЕ потоке,
    /// откуда его отправили — а loadAllPackages() выполняется на фоновом потоке кооперативного
    /// пула Swift Concurrency (её вызывают из Task{} без привязки к MainActor). Без принудительного
    /// перехода на главный поток здесь любое обращение к UIKit у подписчиков — undefined behavior,
    /// на практике проявляющееся как подвисания или краши.
    private func postOnMain(_ name: Notification.Name, userInfo: [AnyHashable: Any]? = nil) {
        if Thread.isMainThread {
            NotificationCenter.default.post(name: name, object: nil, userInfo: userInfo)
        } else {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: name, object: nil, userInfo: userInfo)
            }
        }
    }

    /// Единственная точка правды для дефолтных репозиториев — используется и при первом
    /// запуске, и при сбросе списка источников к дефолту, чтобы не дублировать определение.
    private static var defaultRepositories: [PRRepository] {
        [
            PRRepository(
                name: "Procursus",
                baseURL: URL(string: "https://apt.procurs.us")!,
                distribution: "2000",
                components: ["main"],
                architectures: ["appletvos-arm64"]
            ),
            // Остальные три — самодельные/плоские репозитории без стандартной структуры
            // dists/..., PRNetworkManager сам перебирает вложенный/плоский формат при загрузке.
            PRRepository(name: "palera1n", baseURL: URL(string: "https://repo.palera.in")!),
            PRRepository(name: "fauxly", baseURL: URL(string: "https://fauxly.github.io")!),
            PRRepository(name: "zenzeq", baseURL: URL(string: "https://zenzeq.github.io/tv")!)
        ]
    }
    
    private init() {
        if let saved = loadPersistedRepositories(), !saved.isEmpty {
            repositories = saved
        } else {
            // Первый запуск — сохраняем дефолтные репозитории как отправную точку
            repositories = Self.defaultRepositories
            persistRepositories()
        }
    }

    /// Загружает пакеты параллельно из ВСЕХ подключённых репозиториев и объединяет результат.
    /// Если один репозиторий недоступен/сломан — это не блокирует остальные, ошибка просто
    /// логируется, а от сломанного репо возвращается пустой список вместо падения всего запроса.
    func loadAllPackages() async -> [PRPackage] {
        postOnMain(Self.didStartRefreshingNotification)
        defer { postOnMain(Self.didFinishRefreshingNotification) }

        return await withTaskGroup(of: [PRPackage].self) { group in
            for repository in repositories {
                group.addTask {
                    self.postOnMain(Self.repositoryDidStartRefreshingNotification, userInfo: ["repositoryID": repository.id])
                    defer {
                        self.postOnMain(Self.repositoryDidFinishRefreshingNotification, userInfo: ["repositoryID": repository.id])
                    }
                    do {
                        return try await PRNetworkManager.shared.fetchPackages(from: repository)
                    } catch {
                        print("Pyra: " + String(format: "LOG_REPO_LOAD_FAILED".localized, repository.name, error.localizedDescription))
                        return []
                    }
                }
            }

            var allPackages: [PRPackage] = []
            for await packages in group {
                allPackages.append(contentsOf: packages)
            }
            return allPackages
        }
    }

    /// Совместимость со старым вызовом: раньше бралось только 40 пакетов из первого репозитория.
    /// Теперь — первые 40 из объединённого каталога всех репозиториев.
    func loadFeaturedPackages() async throws -> [PRPackage] {
        Array(await loadAllPackages().prefix(40))
    }

    /// Просит слушателей (дашборд/категории/поиск через PRMainTabBarController) перезагрузить
    /// каталог заново, не меняя сам список репозиториев — например, по нажатию кнопки "обновить".
    func requestRefresh() {
        postOnMain(Self.repositoriesDidChangeNotification)
    }

    /// Добавляет новый репозиторий. Не даёт добавить дубликат по baseURL.
    @discardableResult
    func addRepository(_ repository: PRRepository) -> Bool {
        guard !repositories.contains(where: { $0.baseURL == repository.baseURL }) else {
            return false
        }
        repositories.append(repository)
        persistRepositories()
        postOnMain(Self.repositoriesDidChangeNotification)
        return true
    }

    func removeRepository(_ repository: PRRepository) {
        repositories.removeAll { $0.id == repository.id }
        persistRepositories()
        postOnMain(Self.repositoriesDidChangeNotification)
    }
    
    /// Сбрасывает список источников к дефолту — только Procursus, всё пользовательское
    /// (в том числе битые/недоступные репозитории) стирается.
    func resetToDefault() {
        repositories = Self.defaultRepositories
        persistRepositories()
        postOnMain(Self.repositoriesDidChangeNotification)
    }

    // MARK: - Персистентность

    private func persistRepositories() {
        guard let data = try? JSONEncoder().encode(repositories) else { return }
        UserDefaults.standard.set(data, forKey: userDefaultsKey)
    }

    private func loadPersistedRepositories() -> [PRRepository]? {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else { return nil }
        return try? JSONDecoder().decode([PRRepository].self, from: data)
    }
}
