//
//  PRFreshTracker.swift
//  Pyra
//  Created by Fauxly on 26.09.2026.

import Foundation

/// Ряд "Новое и обновлённое" на главной. В индексе Packages у APT-репозиториев нет даты
/// публикации, поэтому "свежесть" считаем сами: запоминаем, когда впервые увидели каждую
/// пару пакет+версия. Всё, что появилось за последние `window` дней, — свежее.
///
/// Первый запуск (памяти ещё нет) ничего свежим не считает — иначе весь каталог разом
/// оказался бы "новым" и ряд потерял бы смысл.
final class PRFreshTracker {

    static let shared = PRFreshTracker()

    private let defaultsKey = "PRFreshTracker.firstSeen"
    private let window: TimeInterval = 7 * 24 * 60 * 60

    private init() {}

    /// Обновляет память по текущему каталогу и возвращает свежие пакеты (новые сверху).
    func freshPackages(from packages: [PRPackage], limit: Int = 20) -> [PRPackage] {
        let defaults = UserDefaults.standard
        let stored = defaults.dictionary(forKey: defaultsKey) as? [String: Double] ?? [:]
        let isFirstRun = stored.isEmpty
        let now = Date().timeIntervalSince1970

        // Пересобираем словарь только из того, что есть в каталоге сейчас — так он не
        // разрастается бесконечно пакетами из удалённых репозиториев
        var updated: [String: Double] = [:]
        for package in packages {
            let key = "\(package.packageID)|\(package.version)"
            if let seen = stored[key] {
                updated[key] = seen
            } else {
                updated[key] = isFirstRun ? 0 : now
            }
        }
        defaults.set(updated, forKey: defaultsKey)

        guard !isFirstRun else { return [] }

        var seenIDs = Set<String>()
        return packages
            .compactMap { package -> (PRPackage, Double)? in
                let seen = updated["\(package.packageID)|\(package.version)"] ?? 0
                return now - seen < window ? (package, seen) : nil
            }
            .sorted { $0.1 > $1.1 }
            .map { $0.0 }
            .filter { seenIDs.insert($0.packageID).inserted }
            .prefix(limit)
            .map { $0 }
    }
}
