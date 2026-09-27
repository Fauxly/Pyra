//
//  ContentProvider.swift
//  PyraTopShelf
//  Created by Fauxly on 26.09.2026.

import TVServices

/// Верхняя полка Pyra на домашнем экране tvOS: секции "Витрина Pyra" и "Новое и обновлённое".
/// Данные готовит само приложение (PRTopShelfStore) — расширение только читает JSON,
/// своей сети и каталога у него нет. Выбор пакета открывает Pyra на его карточке
/// по ссылке pyra://package/<id>.
class ContentProvider: TVTopShelfContentProvider {

    // Формат — зеркало PRTopShelfStore в приложении. Меняешь там — меняй здесь.
    private struct Item: Codable {
        let id: String
        let name: String
        let subtitle: String
        let iconURL: String?
    }

    private struct Section: Codable {
        let title: String
        let items: [Item]
    }

    private struct Payload: Codable {
        let sections: [Section]
        let updatedAt: Date
    }

    /// На Apple TV — /var/mobile/Library/Caches/...; в симуляторе такого пути нет, поэтому
    /// берём общую папку симулируемого устройства (её видят и приложение, и расширение)
    private static let directoryPath: String = {
        #if targetEnvironment(simulator)
        let shared = ProcessInfo.processInfo.environment["SIMULATOR_SHARED_RESOURCES_DIRECTORY"] ?? NSTemporaryDirectory()
        return shared + "/Library/Caches/com.fauxly.pyra"
        #else
        return "/var/mobile/Library/Caches/com.fauxly.pyra"
        #endif
    }()
    private static let payloadPath = directoryPath + "/TopShelf.json"

    override func loadTopShelfContent(completionHandler: @escaping (TVTopShelfContent?) -> Void) {
        // nil → система показывает стандартную картинку полки (Top Shelf Image из ассетов)
        guard let data = FileManager.default.contents(atPath: Self.payloadPath),
              let payload = try? JSONDecoder().decode(Payload.self, from: data) else {
            completionHandler(nil)
            return
        }

        let collections: [TVTopShelfItemCollection<TVTopShelfSectionedItem>] = payload.sections.compactMap { section in
            let items = section.items.map(Self.makeItem)
            guard !items.isEmpty else { return nil }
            let collection = TVTopShelfItemCollection(items: items)
            collection.title = section.title
            return collection
        }

        completionHandler(collections.isEmpty ? nil : TVTopShelfSectionedContent(sections: collections))
    }

    private static func makeItem(_ item: Item) -> TVTopShelfSectionedItem {
        let shelfItem = TVTopShelfSectionedItem(identifier: item.id)
        shelfItem.title = item.name
        // Иконки твиков квадратные — в квадратной плитке не обрезаются
        shelfItem.imageShape = .square

        if let iconString = item.iconURL, let iconURL = URL(string: iconString) {
            shelfItem.setImageURL(iconURL, for: .screenScale1x)
            shelfItem.setImageURL(iconURL, for: .screenScale2x)
        }

        let encodedID = item.id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? item.id
        if let link = URL(string: "pyra://package/\(encodedID)") {
            shelfItem.displayAction = TVTopShelfAction(url: link)
            shelfItem.playAction = TVTopShelfAction(url: link)
        }
        return shelfItem
    }
}
