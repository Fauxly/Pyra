//
//  PRRepository.swift
//  Pyra
//
//  Created by Fauxly on 06.07.2026.
//

import Foundation

public struct PRRepository: Identifiable, Hashable, Codable {

    public var id: UUID = UUID()

    /// Отображаемое название репозитория
    public var name: String

    /// Базовый URL репозитория
    public var baseURL: URL

    /// Дистрибутив (например: stable, 1800)
    public var distribution: String

    /// Компоненты (обычно "main")
    public var components: [String]

    /// Архитектуры
    public var architectures: [String]

    public init(
        name: String,
        baseURL: URL,
        distribution: String = "1800",
        components: [String] = ["main"],
        architectures: [String] = ["appletvos-arm64", "iphoneos-arm64"]
    ) {
        self.name = name
        self.baseURL = baseURL
        self.distribution = distribution
        self.components = components
        self.architectures = architectures
    }
    
    /// Собирает канонический путь к файлу Packages для APT-репозитория (например,
    /// https://apt.procurs.us/dists/appletvos-arm64/2000/main/binary-appletvos-arm64/Packages).
    /// Собран через appendingPathComponent, а не ручную склейку строк — так не нужно
    /// вручную следить за лишними/пропущенными слэшами между сегментами.
    public var packagesURLs: [URL] {
        let component = components.first ?? "main"
        return architectures.map { arch in
            baseURL
                .appendingPathComponent("dists")
                .appendingPathComponent(arch)
                .appendingPathComponent(distribution)
                .appendingPathComponent(component)
                .appendingPathComponent("binary-\(arch)")
                .appendingPathComponent("Packages")
        }
    }

    /// Строковый вариант — оставлен для обратной совместимости с кодом, который ожидает String.
    public var packagesURL: URL {
        packagesURLs.first!
    }
    
    /// "Плоский" формат APT-репозитория (flat repository format) — Packages лежит прямо
    /// в корне репозитория, без вложенности dists/{arch}/{distribution}/{component}/...
    /// Многие маленькие самодельные Cydia/Sileo/nitoTV-репозитории (например, размещённые
    /// прямо на GitHub Pages) устроены именно так — вложенность dists/ у них попросту нет.
    public var flatPackagesURL: URL {
        baseURL.appendingPathComponent("Packages")
    }

    /// Иконка репозитория по соглашению Cydia/Sileo — CydiaIcon.png в корне репо.
    /// Есть не у всех: вызывающая сторона должна спокойно переживать 404.
    public var iconURL: URL {
        baseURL.appendingPathComponent("CydiaIcon.png")
    }

    /// Собирает ссылку на .deb конкретного пакета. Поле Filename в control-записи (Packages) —
    /// это путь ОТНОСИТЕЛЬНО КОРНЯ репозитория (baseURL), а не относительно dists/, как у индекса
    /// Packages выше. Обычно выглядит как "pool/main/a/pyra/pyra_1.0.0_appletvos-arm64.deb".
    public func downloadURL(for package: PRPackage) -> URL {
        let trimmedFilename = package.filename.hasPrefix("/") ? String(package.filename.dropFirst()) : package.filename
        return baseURL.appendingPathComponent(trimmedFilename)
    }
}
