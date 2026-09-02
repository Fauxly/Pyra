//
//  PRStatusParser.swift
//  Pyra
//
import Foundation

public final class PRStatusParser {

    public static let shared = PRStatusParser()

    // Определяем путь к файлу в зависимости от префикса джейлбрейка
    private var statusFilePath: String {
        // Проверяем наличие rootless-префикса palera1n
        let rootlessPath = "/var/jb/var/lib/dpkg/status"
        if FileManager.default.fileExists(atPath: rootlessPath) {
            return rootlessPath
        }
        return "/var/lib/dpkg/status" // Стандартный rootful путь
    }

    public func readInstalledPackages() -> [PRInstalledPackage] {
        let path = statusFilePath

        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            print("Pyra: " + String(format: "LOG_STPRUS_FILE_ERROR".localized, path))
            return getMockPackages() // Если запускаем на симуляторе Mac — отдаем заглушки
        }

        var installedPackages: [PRInstalledPackage] = []

        // В файле dpkg status каждый пакет разделен двойным переносом строки
        let rawPackages = content.components(separatedBy: "\n\n")

        for rawPkg in rawPackages {
            if rawPkg.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { continue }

            let fields = parseFields(from: rawPkg)

            guard let id = fields["package"], !id.isEmpty else { continue }

            // Поле Status — это три слова: <want> <flag> <status>, например "install ok installed".
            // Возможные значения третьего слова при реально распакованном на диск пакете:
            //   "installed"       — полностью установлен и настроен
            //   "half-configured" — файлы на диске, но postinst не завершился (часто из-за
            //                       неудовлетворённых зависимостей — dpkg -i ставит файлы,
            //                       но помечает пакет как не полностью настроенный)
            //   "unpacked"        — файлы распакованы, но configure ещё не запускался
            //   "half-installed"  — установка прервалась на полпути (реально сломан)
            //
            // Показываем пользователю все, кроме явно деинсталлированных ("not-installed",
            // "config-files") — раз файлы на диске и пакет работает, человек должен его
            // видеть в списке и иметь возможность удалить.
            guard let status = fields["status"] else { continue }
            let statusWords = status.split(separator: " ")
            guard statusWords.count == 3 else { continue }
            
            let wantState = statusWords[0]    // "install", "deinstall", "purge" и т.д.
            let currentState = statusWords[2] // "installed", "half-configured", "unpacked", "not-installed" и т.д.
            
            // Пропускаем только если пакет явно помечен как удалённый или отсутствующий
            let excludedStates: Set<Substring> = ["not-installed", "config-files"]
            if excludedStates.contains(currentState) { continue }
            // Если пользователь пометил пакет на удаление, но файлы ещё на диске — тоже пропускаем
            if wantState == "deinstall" || wantState == "purge" { continue }

            let name = fields["name"] ?? id
            let version = fields["version"] ?? ""
            let description = formattedDescription(fields["description"] ?? "")
            let section = fields["section"] ?? ""

            let package = PRInstalledPackage(id: id, name: name, version: version, description: description, section: section)
            installedPackages.append(package)
        }

        // Сортируем по алфавиту
        return installedPackages.sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    /// Быстрая проверка: пакет реально стоит в dpkg status?
    /// Используется для верификации после установки — не доверяем exit code,
    /// а проверяем факт записи в базе dpkg.
    public func isPackageInstalled(id: String) -> Bool {
        readInstalledPackages().contains { $0.id.lowercased() == id.lowercased() }
    }
    
    // MARK: - Private

    /// Разбирает один блок control-полей (одна запись пакета) в словарь [ключ в нижнем регистре: значение].
    /// Учитывает многострочные поля (например Description) через строки-продолжения с ведущим пробелом.
    private func parseFields(from rawRecord: String) -> [String: String] {
        var fields: [String: String] = [:]
        var lastKey: String?

        let lines = rawRecord.components(separatedBy: .newlines)

        for rawLine in lines {
            if let first = rawLine.first, (first == " " || first == "\t"), let key = lastKey {
                let continuation = String(rawLine.dropFirst())
                let piece = (continuation.trimmingCharacters(in: .whitespaces) == ".") ? "" : continuation
                let existing = fields[key] ?? ""
                fields[key] = existing.isEmpty ? piece : existing + "\n" + piece
                continue
            }

            guard let colonIndex = rawLine.firstIndex(of: ":") else { continue }

            let key = rawLine[rawLine.startIndex..<colonIndex]
                .trimmingCharacters(in: .whitespaces)
                .lowercased()
            let value = rawLine[rawLine.index(after: colonIndex)...]
                .trimmingCharacters(in: .whitespaces)

            fields[key] = value
            lastKey = key
        }

        return fields
    }

    private func formattedDescription(_ raw: String) -> String {
        guard !raw.isEmpty else { return "" }
        let components = raw.components(separatedBy: "\n")
        guard components.count > 1 else { return raw }
        let synopsis = components[0]
        let details = components.dropFirst().joined(separator: "\n")
        return details.isEmpty ? synopsis : "\(synopsis)\n\n\(details)"
    }

    // Заглушки для теста на симуляторе Xcode, чтобы экран не был пустым
    private func getMockPackages() -> [PRInstalledPackage] {
        return [
            PRInstalledPackage(id: "org.coolstar.tweakinject", name: "TweakInject", version: "1.3.0", description: "Тайм-инъекции для tvOS твиков", section: "Tweaks"),
            PRInstalledPackage(id: "com.nito.update", name: "nito update helper", version: "0.4-2", description: "Помощник обновления системных демонов", section: "Utilities"),
            PRInstalledPackage(id: "bash", name: "Bash Terminal Shell", version: "5.2.15", description: "Командная оболочка Bourne-Again SHell", section: "Terminal")
        ]
    }
}
