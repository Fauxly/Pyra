//
//  PRPathManager.swift
//  Pyra
//
//  Created by Fix’s Trick’s on 07.07.2026.
//
import Foundation

public final class PRPathManager {
    
    public static let shared = PRPathManager()
    
    /// Текущий префикс для POSIX-окружения.
    /// Будет пустой строкой "" для твоей Rootful системы.
    public let jbPrefix: String
    
    /// Флаг, определяющий, работает ли приложение в Rootless режиме
    public let isRootless: Bool
    
    private init() {
        // Проверяем существование /var/jb
        if FileManager.default.fileExists(atPath: "/var/jb") {
            self.jbPrefix = "/var/jb"
            self.isRootless = true
            print("Pyra: " + "LOG_DETECTED_ROOTLESS".localized)
        } else {
            self.jbPrefix = ""
            self.isRootless = false
            print("Pyra: " + "LOG_DETECTED_ROOTFUL".localized)
        }
    }
    
    /// Обертка для сборки любого POSIX-пути
    public func makePath(_ path: String) -> String {
        if isRootless && path.hasPrefix("/var/jb") {
            return path
        }
        return jbPrefix + path
    }
}
