//
//  PRTopShelfStore.swift
//  Pyra
//  Created by Fauxly on 26.09.2026.

import Foundation
import TVServices

/// Данные для верхней полки (Top Shelf) домашнего экрана tvOS. Расширение PyraTopShelf
/// работает отдельным процессом и сети/каталога приложения не видит, поэтому приложение
/// после каждой загрузки каталога складывает витрину в JSON по фиксированному пути,
/// а расширение просто читает этот файл.
///
/// Путь вне контейнеров намеренно: Pyra без песочницы (no-container), а расширению доступ
/// на чтение выдаётся sandbox-исключением в entitlements-topshelf.plist.
/// Формат дублируется в PyraTopShelf/ContentProvider.swift — меняешь здесь, меняй и там.
final class PRTopShelfStore {

    static let shared = PRTopShelfStore()

    /// На Apple TV — /var/mobile/Library/Caches/...; в симуляторе такого пути нет, поэтому
    /// берём общую папку симулируемого устройства (её видят и приложение, и расширение)
    static let directoryPath: String = {
        #if targetEnvironment(simulator)
        let shared = ProcessInfo.processInfo.environment["SIMULATOR_SHARED_RESOURCES_DIRECTORY"] ?? NSTemporaryDirectory()
        return shared + "/Library/Caches/com.fauxly.pyra"
        #else
        return "/var/mobile/Library/Caches/com.fauxly.pyra"
        #endif
    }()
    static let payloadPath = directoryPath + "/TopShelf.json"

    struct Item: Codable {
        let id: String
        let name: String
        let subtitle: String
        let iconURL: String?
    }

    struct Section: Codable {
        let title: String
        let items: [Item]
    }

    struct Payload: Codable {
        let sections: [Section]
        let updatedAt: Date
    }

    private init() {}

    /// Сохранить витрину и "Новое" и попросить систему перечитать полку
    func save(featured: [PRPackage], fresh: [PRPackage]) {
        var sections: [Section] = []
        if !featured.isEmpty {
            sections.append(Section(title: "TOPSHELF_FEATURED".localized, items: featured.map(Self.item)))
        }
        if !fresh.isEmpty {
            sections.append(Section(title: "DASHBOARD_FRESH".localized, items: fresh.prefix(12).map(Self.item)))
        }
        guard !sections.isEmpty else { return }

        let payload = Payload(sections: sections, updatedAt: Date())
        do {
            try FileManager.default.createDirectory(atPath: Self.directoryPath, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(payload)
            // Атомарно: расширение может читать файл ровно в момент записи
            try data.write(to: URL(fileURLWithPath: Self.payloadPath), options: .atomic)
            // Файл должен читаться и из процесса расширения (он не root)
            try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: Self.payloadPath)
            TVTopShelfContentProvider.topShelfContentDidChange()
        } catch {
            print("Pyra: top shelf save failed — \(error.localizedDescription)")
        }
    }

    private static func item(for package: PRPackage) -> Item {
        var subtitle = "v\(package.version)"
        if let repo = package.sourceRepository?.name { subtitle += " · \(repo)" }
        return Item(id: package.packageID, name: package.name, subtitle: subtitle, iconURL: package.iconURL)
    }
}
