//  Created by Fauxly on 06.07.2026.

import Foundation

final class PRDownloadManager {

    static let shared = PRDownloadManager()

    private let session: URLSession

    private init() {
        // .deb файлы могут весить десятки МБ — дефолтный таймаут URLSession.shared (60 сек
        // на ресурс) может быть маловат на медленном соединении Apple TV.
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForResource = 180
        self.session = URLSession(configuration: configuration)
    }

    func download(
        package: PRPackage,
        repository: PRRepository
    ) async throws -> URL {

        // Filename может не распарситься (пустая строка по умолчанию у PRPackage) —
        // без этой проверки downloadURL(for:) свёлся бы к baseURL репозитория,
        // а destination в PRFileManager рисковал бы совпасть с самой папкой загрузок.
        guard !package.filename.isEmpty else {
            throw NSError(
                domain: "Pyra",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: String(format: "ERROR_NO_FILENAME".localized, package.packageID)]
            )
        }

        let remoteURL = repository.downloadURL(for: package)

        print("Downloading:")
        print(remoteURL.absoluteString)

        let (tempURL, response) = try await session.download(from: remoteURL)

        guard let http = response as? HTTPURLResponse,
              http.statusCode == 200 else {

            throw NSError(
                domain: "Pyra",
                code: -1,
                userInfo: [
                    NSLocalizedDescriptionKey: "ERROR_DOWNLOAD_FAILED".localized
                ])
        }

        let destination = PRFileManager.shared.destinationURL(for: package)

        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }

        try FileManager.default.moveItem(at: tempURL, to: destination)

        return destination
    }
}
