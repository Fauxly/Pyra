//
//  PRLogger.swift
//  Pyra
//  Created by Fauxly on 06.07.2026.

import Foundation

enum PRLogger {

    static var logFileURL: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("pyra_diagnostic.log")
    }

    /// Перенаправляет stdout/stderr в файл — вызвать ОДИН раз, максимально рано при старте
    /// приложения (до первого print), в AppDelegate. Захватывает вообще весь консольный вывод,
    /// включая уже существующие print() по всему проекту — не нужно переписывать каждый
    /// вызов на какой-то отдельный метод логгера.
    static func start() {
        freopen(logFileURL.path, "a+", stdout)
        freopen(logFileURL.path, "a+", stderr)
        print("\n--- Pyra запущен: \(Date()) ---")
    }

    static func readLog() -> String {
        (try? String(contentsOf: logFileURL, encoding: .utf8)) ?? ""
    }

    static func clearLog() {
        try? "".write(to: logFileURL, atomically: true, encoding: .utf8)
    }

    /// Размер файла лога — на случай если он вырастет большим за долгую сессию
    static func logFileSize() -> Int64 {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: logFileURL.path) else {
            return 0
        }
        return (attributes[.size] as? Int64) ?? 0
    }
}
