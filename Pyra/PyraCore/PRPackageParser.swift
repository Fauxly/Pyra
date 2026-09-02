//
//  PRPackageParser.swift
//  Pyra
//  Created by Fauxly on 06.07.2026.

import Foundation

/// Парсит control-файлы формата Debian Packages (в том числе Cydia/Procursus-совместимые репозитории)
/// в массив PRPackage.
///
/// Формат:
/// - Записи о пакетах разделены пустой строкой.
/// - Каждое поле — это "Key: значение" на отдельной строке.
/// - Многострочные поля (чаще всего Description) продолжаются строками,
///   начинающимися с пробела; строка вида " ." означает пустую строку внутри описания.
public final class PRPackageParser {

    public init() {}

    public func parse(_ rawText: String) -> [PRPackage] {
        // Нормализуем переносы строк (сервер может отдать \r\n)
        let normalized = rawText.replacingOccurrences(of: "\r\n", with: "\n")

        // Записи разделены пустой строкой. Разбиваем построчно и группируем сами,
        // чтобы не терять данные из-за лишних пустых строк подряд.
        let lines = normalized.components(separatedBy: "\n")

        var records: [[String]] = []
        var currentRecord: [String] = []

        for line in lines {
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                if !currentRecord.isEmpty {
                    records.append(currentRecord)
                    currentRecord = []
                }
            } else {
                currentRecord.append(line)
            }
        }
        if !currentRecord.isEmpty {
            records.append(currentRecord)
        }

        return records.compactMap { parseRecord($0) }
    }

    // MARK: - Private

    private func parseRecord(_ lines: [String]) -> PRPackage? {
        let fields = parseFields(from: lines)

        // Package и Version — обязательные поля по спецификации Debian control-файлов.
        // Без них запись бессмысленна, пропускаем.
        guard let packageID = fields["package"], !packageID.isEmpty,
              let version = fields["version"], !version.isEmpty else {
            return nil
        }

        // Name — Cydia-расширение поля control-файла (человекочитаемое название твика).
        // Не все репозитории его указывают, тогда используем packageID как запасной вариант.
        let name = fields["name"] ?? packageID

        let architecture = fields["architecture"] ?? "appletvos-arm64"
        let section = fields["section"] ?? "Unknown"
        let filename = fields["filename"] ?? ""
        let description = formattedDescription(fields["description"] ?? "")

        // Author в некоторых репозиториях отсутствует, вместо него указывают Maintainer
        let author = fields["author"] ?? fields["maintainer"]

        let depends = fields["depends"]

        // Icon — Cydia-расширение для прямой ссылки на иконку твика
        let iconURL = fields["icon"]

        return PRPackage(
            packageID: packageID,
            name: name,
            version: version,
            architecture: architecture,
            description: description,
            filename: filename,
            section: section,
            author: author,
            depends: depends,
            iconURL: iconURL
        )
    }

    /// Разбирает строки одной записи в словарь [ключ в нижнем регистре: значение].
    /// Учитывает многострочные поля через строки-продолжения (начинаются с пробела/таба).
    private func parseFields(from lines: [String]) -> [String: String] {
        var fields: [String: String] = [:]
        var lastKey: String?

        for rawLine in lines {
            // Строка-продолжение: начинается с пробела или таба и относится к предыдущему полю
            if let first = rawLine.first, (first == " " || first == "\t"), let key = lastKey {
                let continuation = String(rawLine.dropFirst())

                // " ." в Debian control-файлах означает пустую строку внутри многострочного описания
                let piece = (continuation.trimmingCharacters(in: .whitespaces) == ".") ? "" : continuation

                let existing = fields[key] ?? ""
                fields[key] = existing.isEmpty ? piece : existing + "\n" + piece
                continue
            }

            // Обычная строка вида "Key: значение"
            guard let colonIndex = rawLine.firstIndex(of: ":") else {
                // Строка без двоеточия и без ведущего пробела — повреждённая запись, пропускаем строку
                continue
            }

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

    /// Приводит многострочное Description-поле к читаемому виду:
    /// краткое описание (то, что шло сразу после "Description:") + пустая строка + подробности.
    private func formattedDescription(_ raw: String) -> String {
        guard !raw.isEmpty else { return "" }

        let components = raw.components(separatedBy: "\n")
        guard components.count > 1 else { return raw }

        let synopsis = components[0]
        let details = components.dropFirst().joined(separator: "\n")

        return details.isEmpty ? synopsis : "\(synopsis)\n\n\(details)"
    }
}
