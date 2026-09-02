//
//  PRDependencyChecker.swift
//  Pyra
//  Created by Fauxly on 06.07.2026.

import UIKit

public struct PRDependencyRequirement {
    public let packageID: String
    public let versionOperator: String?  // ">=", "<=", "=", ">>", "<<"
    public let version: String?
    
    /// Человекочитаемое представление для показа в UI: "mobilesubstrate" или "firmware (>= 15.0)"
    public var displayString: String {
        if let op = versionOperator, let version = version {
            return "\(packageID) (\(op) \(version))"
        }
        return packageID
    }
}

public enum PRDependencyChecker {
    
    /// Разбирает поле Depends control-файла: "firmware (>= 15.0), mobilesubstrate, a | b (>= 1.0)"
    /// Внешний массив — обязательные группы (через запятую, ВСЕ должны быть удовлетворены),
    /// внутренний — альтернативы через "|" (достаточно ОДНОЙ из них, как в apt/dpkg).
    static func parse(_ raw: String) -> [[PRDependencyRequirement]] {
        raw.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { group in
                group.components(separatedBy: "|").compactMap { parseSingle($0) }
            }
    }
    
    private static func parseSingle(_ raw: String) -> PRDependencyRequirement? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        // Формат "packageID (>= 1.0)" — версия в скобках, либо просто "packageID" без версии
        if let openParen = trimmed.firstIndex(of: "("),
           let closeParen = trimmed.firstIndex(of: ")"),
           openParen < closeParen {
            let name = trimmed[trimmed.startIndex..<openParen].trimmingCharacters(in: .whitespaces)
            let constraint = trimmed[trimmed.index(after: openParen)..<closeParen].trimmingCharacters(in: .whitespaces)
            
            // Порядок важен: ">=" нужно проверить раньше ">", иначе он никогда не совпадёт первым
            let operators = [">=", "<=", "==", "=", ">>", "<<"]
            for op in operators where constraint.hasPrefix(op) {
                let version = constraint.dropFirst(op.count).trimmingCharacters(in: .whitespaces)
                return PRDependencyRequirement(packageID: name, versionOperator: op, version: version)
            }
            return PRDependencyRequirement(packageID: name, versionOperator: nil, version: nil)
        }
        
        return PRDependencyRequirement(packageID: trimmed, versionOperator: nil, version: nil)
    }
    
    /// Возвращает список неудовлетворённых ОБЯЗАТЕЛЬНЫХ групп (для каждой — ни одна
    /// из альтернатив не подошла). Пустой массив — все зависимости удовлетворены.
    public static func missingDependencies(for package: PRPackage) -> [[PRDependencyRequirement]] {
        guard let raw = package.depends, !raw.isEmpty else { return [] }
        
        let installed = PRStatusParser.shared.readInstalledPackages()
        let groups = parse(raw)
        
        return groups.filter { alternatives in
            !alternatives.contains { isSatisfied($0, installed: installed) }
        }
    }
    
    private static func isSatisfied(_ requirement: PRDependencyRequirement, installed: [PRInstalledPackage]) -> Bool {
        // "firmware" — не настоящий dpkg-пакет, это версия самой прошивки tvOS
        if requirement.packageID.lowercased() == "firmware" {
            guard let op = requirement.versionOperator, let required = requirement.version else {
                return true
            }
            return compareVersions(UIDevice.current.systemVersion, op, required)
        }
        
        guard let match = installed.first(where: { $0.id.lowercased() == requirement.packageID.lowercased() })
            // Если прямого совпадения нет — проверяем поле Provides: у всех установленных
            // пакетов. Это стандартный Debian-механизм: один пакет может "предоставлять" другой
            // (например, ElleKit предоставляет mobilesubstrate через Provides: mobilesubstrate,
            // и зависимость на mobilesubstrate должна считаться удовлетворённой).
            ?? installed.first(where: { providedPackageIDs(by: $0).contains(requirement.packageID) })
        else {
            return false
        }
        
        guard let op = requirement.versionOperator, let required = requirement.version else {
            return true
        }
        
        return compareVersions(match.version, op, required)
    }
    
    // MARK: - Сравнение версий
    
    /// Читает поле Provides: из dpkg status для конкретного пакета.
    /// Provides — список через запятую: "mobilesubstrate, libhooker"
    private static func providedPackageIDs(by package: PRInstalledPackage) -> [String] {
        let statusPath = FileManager.default.fileExists(atPath: "/var/jb/var/lib/dpkg/status")
            ? "/var/jb/var/lib/dpkg/status"
            : "/var/lib/dpkg/status"
        
        guard let content = try? String(contentsOfFile: statusPath, encoding: .utf8) else { return [] }
        
        let blocks = content.components(separatedBy: "\n\n")
        for block in blocks {
            guard block.contains("Package: \(package.id)") else { continue }
            guard let providesLine = block.components(separatedBy: "\n")
                .first(where: { $0.lowercased().hasPrefix("provides:") }) else { continue }
            
            let value = providesLine.drop(while: { $0 != ":" }).dropFirst()
                .trimmingCharacters(in: .whitespaces)
            return value.components(separatedBy: ",")
                .map { entry -> String in
                    // Отбрасываем версию в скобках: "mobilesubstrate (= 99)" → "mobilesubstrate"
                    let trimmed = entry.trimmingCharacters(in: .whitespaces)
                    if let parenStart = trimmed.firstIndex(of: "(") {
                        return String(trimmed[trimmed.startIndex..<parenStart]).trimmingCharacters(in: .whitespaces)
                    }
                    return trimmed
                }
                .filter { !$0.isEmpty }
        }
        return []
    }
    
    /// Упрощённое сравнение версий в духе dpkg: делим на числовые/нечисловые сегменты
    /// и сравниваем их по очереди. Не претендует на полное соответствие схеме версий
    /// Debian (эпохи вида "2:1.0", тильды для pre-release), но покрывает подавляющее
    /// большинство реальных случаев вида "1.2.4" vs "1.10.0".
    static func compareVersions(_ lhs: String, _ op: String, _ rhs: String) -> Bool {
        let result = compare(lhs, rhs)
        switch op {
        case ">=": return result >= 0
        case "<=": return result <= 0
        case "=", "==": return result == 0
        case ">>": return result > 0
        case "<<": return result < 0
        default: return true
        }
    }
    
    private static func compare(_ lhs: String, _ rhs: String) -> Int {
        let lhsParts = splitVersion(lhs)
        let rhsParts = splitVersion(rhs)
        
        for i in 0..<max(lhsParts.count, rhsParts.count) {
            let l = i < lhsParts.count ? lhsParts[i] : ""
            let r = i < rhsParts.count ? rhsParts[i] : ""
            
            if let lNum = Int(l), let rNum = Int(r) {
                if lNum != rNum { return lNum < rNum ? -1 : 1 }
            } else if l != r {
                return l < r ? -1 : 1
            }
        }
        return 0
    }
    
    private static func splitVersion(_ version: String) -> [String] {
        var parts: [String] = []
        var current = ""
        var lastWasDigit: Bool?
        
        for char in version {
            let isDigit = char.isNumber
            if let last = lastWasDigit, last != isDigit {
                parts.append(current)
                current = ""
            }
            if char != "." && char != "-" {
                current.append(char)
            }
            lastWasDigit = isDigit
        }
        if !current.isEmpty { parts.append(current) }
        return parts
    }
}
