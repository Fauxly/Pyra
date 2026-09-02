//
//  PRFileManager.swift
//  Pyra
//
//  Created by Fauxly on 06.07.2026.
//

import Foundation

final class PRFileManager {

    static let shared = PRFileManager()

    private init() {}

    var downloadsDirectory: URL {

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Pyra")

        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(
                at: url,
                withIntermediateDirectories: true
            )
        }

        return url
    }

    func destinationURL(for package: PRPackage) -> URL {
        let lastComponent = (package.filename as NSString).lastPathComponent

        // Если Filename не распарсился (пусто) или lastPathComponent схлопнулся в пустую
        // строку/точку — appendingPathComponent("") фактически ничего не добавляет, и
        // destination оказался бы РАВЕН самой downloadsDirectory. Дальше по коду в
        // PRDownloadManager это привело бы к удалению всей папки загрузок целиком
        // (fileExists видит папку, removeItem её стирает). Подставляем безопасное имя
        // на основе packageID+version, чтобы такого пути в принципе не могло возникнуть.
        guard !lastComponent.isEmpty, lastComponent != ".", lastComponent != "/" else {
            let fallbackName = "\(package.packageID)_\(package.version).deb"
            return downloadsDirectory.appendingPathComponent(fallbackName)
        }

        return downloadsDirectory.appendingPathComponent(lastComponent)
    }

    /// Удаляет скачанный .deb после установки — иначе временные файлы копятся
    /// в downloadsDirectory безгранично между запусками приложения.
    func removeDownloadedFile(for package: PRPackage) {
        let url = destinationURL(for: package)
        try? FileManager.default.removeItem(at: url)
    }
    
    /// Суммарный размер всех файлов в downloadsDirectory — для экрана настроек.
    /// Возвращает 0, если папку прочитать не удалось (например, пустая — это не ошибка).
    func cacheSize() -> Int64 {
        let fileManager = FileManager.default
        guard let urls = try? fileManager.contentsOfDirectory(
            at: downloadsDirectory,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }
        
        return urls.reduce(Int64(0)) { total, url in
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            return total + Int64(size)
        }
    }
    
    /// Удаляет ВСЕ файлы в downloadsDirectory разом (кнопка "Очистить кэш" в настройках) —
    /// не только конкретный package, как removeDownloadedFile. Саму папку не трогаем,
    /// downloadsDirectory сама пересоздаст её при следующем обращении, если понадобится.
    func clearCache() {
        let fileManager = FileManager.default
        guard let urls = try? fileManager.contentsOfDirectory(at: downloadsDirectory, includingPropertiesForKeys: nil) else {
            return
        }
        for url in urls {
            try? fileManager.removeItem(at: url)
        }
    }
}
