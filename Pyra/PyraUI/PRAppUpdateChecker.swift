//
//  PRAppUpdateChecker.swift
//  Pyra
//  Created by Fauxly on 06.07.2026.

import Foundation

struct PRAppUpdateInfo {
    let version: String
    let downloadURL: URL
}

enum PRAppUpdateChecker {

    // Поменяй, если репозиторий когда-нибудь переедет на другой аккаунт/имя
    private static let repoOwner = "fauxly"
    private static let repoName = "Pyra"

    private static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    /// Возвращает информацию об обновлении, если на GitHub есть версия новее текущей.
    /// nil — либо обновлений нет, либо релиз не содержит .deb-ассета.
    static func checkForUpdate() async throws -> PRAppUpdateInfo? {
        let apiURL = URL(string: "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest")!

        var request = URLRequest(url: apiURL)
        // GitHub API требует явный Accept-заголовок и просит указывать User-Agent —
        // без него отдаёт 403 на некоторые запросы.
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Pyra-tvOS", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "PRAppUpdateChecker", code: -1, userInfo: [NSLocalizedDescriptionKey: "ERROR_NO_SERVER_RESPONSE".localized])
        }

        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let tagName = json["tag_name"] as? String,
            let assets = json["assets"] as? [[String: Any]]
        else {
            throw NSError(domain: "PRAppUpdateChecker", code: -2, userInfo: [NSLocalizedDescriptionKey: "ERROR_UTF8_DECODE".localized])
        }

        // Тег обычно вида "v1.0.7" — отбрасываем ведущую "v" для сравнения через PRDependencyChecker
        let remoteVersion = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName

        guard PRDependencyChecker.compareVersions(remoteVersion, ">>", currentVersion) else {
            return nil
        }

        // В релизе два пакета: rootful (appletvos-arm64) и rootless (iphoneos-arm64).
        // Берём тот, что под текущее окружение; если такого нет (старые релизы с одним
        // пакетом) — любой .deb, как раньше.
        let preferredArchitecture = PRPathManager.shared.isRootless ? "iphoneos-arm64" : "appletvos-arm64"
        let debAssets = assets.filter { ($0["name"] as? String)?.hasSuffix(".deb") == true }
        let matchingAsset = debAssets.first { ($0["name"] as? String)?.contains(preferredArchitecture) == true }

        guard
            let debAsset = matchingAsset ?? debAssets.first,
            let downloadURLString = debAsset["browser_download_url"] as? String,
            let downloadURL = URL(string: downloadURLString)
        else {
            return nil
        }

        return PRAppUpdateInfo(version: remoteVersion, downloadURL: downloadURL)
    }
}
