//
//  PRDepictionLoader.swift
//  Pyra
//  Created by Fauxly on 27.09.2026.

import Foundation

/// Нативная страница пакета в формате Sileo (поле SileoDepiction в Packages).
/// Из всего богатства формата берём то, что осмысленно на ТВ: скриншоты и список изменений.
struct PRDepiction {

    struct Screenshot {
        let url: URL
        /// Ширина / высота — из itemSize блока скриншотов ("{160, 284}"), по умолчанию 16:9
        let aspectRatio: CGFloat
    }

    let screenshots: [Screenshot]
    /// Текст вкладки Changelog, приведённый к простому тексту; nil — вкладки нет
    let changelog: String?

    var isEmpty: Bool { screenshots.isEmpty && (changelog ?? "").isEmpty }
}

/// Загружает и разбирает Sileo-депикшены. Формат — дерево view-объектов с полем "class":
/// DepictionTabView → tabs[] → views[] (DepictionStackView вкладывает ещё views[]).
/// Нас интересуют DepictionScreenshotsView (скриншоты) и текстовые view во вкладке Changelog.
final class PRDepictionLoader {

    static let shared = PRDepictionLoader()

    private var cache: [URL: PRDepiction] = [:]
    private let lock = NSLock()
    private let session: URLSession

    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 10
        session = URLSession(configuration: configuration)
    }

    /// nil — у пакета нет депикшена, он недоступен или в нём нет ничего полезного для нас
    func depiction(for package: PRPackage) async -> PRDepiction? {
        guard let raw = package.sileoDepictionURL?.trimmingCharacters(in: .whitespaces), !raw.isEmpty,
              let url = Self.resolve(raw, relativeTo: package.sourceRepository?.baseURL) else { return nil }

        lock.lock()
        let cached = cache[url]
        lock.unlock()
        if let cached { return cached }

        guard let (data, response) = try? await session.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }

        let depiction = Self.parse(json, baseURL: url)
        guard !depiction.isEmpty else { return nil }

        lock.lock()
        cache[url] = depiction
        lock.unlock()
        return depiction
    }

    // MARK: - Разбор

    private static func parse(_ root: [String: Any], baseURL: URL) -> PRDepiction {
        var screenshots: [PRDepiction.Screenshot] = []
        var changelogParts: [String] = []

        let tabs = root["tabs"] as? [[String: Any]] ?? [root]
        for tab in tabs {
            let tabName = (tab["tabname"] as? String ?? "").lowercased()
            let isChangelog = tabName.contains("change") || tabName.contains("измен") || tabName.contains("history")
            let views = tab["views"] as? [[String: Any]] ?? []
            walk(views, baseURL: baseURL, collectText: isChangelog, screenshots: &screenshots, text: &changelogParts)
        }

        let changelog = changelogParts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")

        return PRDepiction(screenshots: screenshots, changelog: changelog.isEmpty ? nil : changelog)
    }

    /// Рекурсивный обход дерева view. collectText == false — текст этой вкладки не собираем
    /// (скриншоты собираем всегда, с какой бы вкладки они ни были).
    private static func walk(_ views: [[String: Any]],
                             baseURL: URL,
                             collectText: Bool,
                             screenshots: inout [PRDepiction.Screenshot],
                             text: inout [String]) {
        for view in views {
            let className = view["class"] as? String ?? ""

            switch className {
            case "DepictionScreenshotsView", "DepictionScreenshotView":
                let aspect = aspectRatio(from: view["itemSize"] as? String) ?? 16.0 / 9.0
                for shot in view["screenshots"] as? [[String: Any]] ?? [] {
                    if let raw = shot["url"] as? String, let url = resolve(raw, relativeTo: baseURL) {
                        screenshots.append(.init(url: url, aspectRatio: aspect))
                    }
                }
            case "DepictionHeaderView", "DepictionSubheaderView":
                if collectText, let title = view["title"] as? String { text.append(title.uppercased()) }
            case "DepictionMarkdownView":
                if collectText, let markdown = view["markdown"] as? String { text.append(plainText(fromMarkdown: markdown)) }
            case "DepictionLabelView":
                if collectText, let label = view["text"] as? String { text.append(label) }
            case "DepictionTableTextView":
                if collectText, let title = view["title"] as? String, let value = view["text"] as? String {
                    text.append("\(title): \(value)")
                }
            default:
                break
            }

            // DepictionStackView и прочие контейнеры — идём глубже
            if let nested = view["views"] as? [[String: Any]] {
                walk(nested, baseURL: baseURL, collectText: collectText, screenshots: &screenshots, text: &text)
            }
        }
    }

    /// "{160, 284}" → 160/284
    private static func aspectRatio(from itemSize: String?) -> CGFloat? {
        guard let itemSize else { return nil }
        let numbers = itemSize
            .components(separatedBy: CharacterSet(charactersIn: "0123456789.").inverted)
            .compactMap { Double($0) }
        guard numbers.count >= 2, numbers[0] > 0, numbers[1] > 0 else { return nil }
        return CGFloat(numbers[0] / numbers[1])
    }

    private static func resolve(_ raw: String, relativeTo base: URL?) -> URL? {
        if let absolute = URL(string: raw), absolute.scheme != nil { return absolute }
        guard let base else { return nil }
        return URL(string: raw, relativeTo: base)?.absoluteURL
    }

    /// Упрощённый markdown → текст: убираем разметку заголовков, выделения, код и ссылки
    private static func plainText(fromMarkdown markdown: String) -> String {
        var text = markdown
        // [текст](ссылка) → текст
        text = text.replacingOccurrences(of: #"\[([^\]]*)\]\([^)]*\)"#, with: "$1", options: .regularExpression)
        // ![alt](img) → убрать
        text = text.replacingOccurrences(of: #"!\[[^\]]*\]\([^)]*\)"#, with: "", options: .regularExpression)
        // HTML-теги (некоторые депикшены шлют <br> и т.п.)
        text = text.replacingOccurrences(of: #"<br\s*/?>"#, with: "\n", options: [.regularExpression, .caseInsensitive])
        text = text.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
        // # заголовки, **жирный**, *курсив*, `код`
        text = text.replacingOccurrences(of: #"(?m)^#{1,6}\s*"#, with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: #"[*_`]{1,3}"#, with: "", options: .regularExpression)
        // "- пункт" / "* пункт" → "• пункт"
        text = text.replacingOccurrences(of: #"(?m)^\s*[-+]\s+"#, with: "• ", options: .regularExpression)
        return text
    }
}
