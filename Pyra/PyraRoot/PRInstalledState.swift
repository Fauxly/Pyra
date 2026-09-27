//
//  PRInstalledState.swift
//  Pyra
//  Created by Fauxly on 26.09.2026.

import Foundation

/// Кэш "что сейчас установлено" для быстрых проверок из UI. PRStatusParser каждый раз
/// заново читает и парсит весь dpkg status — это нормально для одного экрана, но не для
/// сотни плиток каталога, каждая из которых хочет знать свой статус. Здесь status читается
/// один раз и обновляется явно: после установки/удаления и при загрузке каталога.
final class PRInstalledState {

    static let shared = PRInstalledState()

    /// Шлётся на главном потоке после каждого refresh() — плитки и экраны перерисовывают значки
    static let didChangeNotification = Notification.Name("PRInstalledState.didChange")

    enum Status: Equatable {
        case notInstalled
        case installed
        case updateAvailable(installedVersion: String)
    }

    private var versions: [String: String] = [:]
    private var isLoaded = false
    private let lock = NSLock()

    private init() {}

    /// Перечитать dpkg status и оповестить UI
    func refresh() {
        reload()
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
        }
    }

    func installedVersion(of packageID: String) -> String? {
        lock.lock()
        let needsLoad = !isLoaded
        lock.unlock()
        if needsLoad { reload() }

        lock.lock()
        defer { lock.unlock() }
        return versions[packageID.lowercased()]
    }

    func status(for package: PRPackage) -> Status {
        guard let installed = installedVersion(of: package.packageID) else { return .notInstalled }
        if PRDependencyChecker.compareVersions(package.version, ">>", installed) {
            return .updateAvailable(installedVersion: installed)
        }
        return .installed
    }

    private func reload() {
        var map: [String: String] = [:]
        for package in PRStatusParser.shared.readInstalledPackages() {
            map[package.id.lowercased()] = package.version
        }
        lock.lock()
        versions = map
        isLoaded = true
        lock.unlock()
    }
}
