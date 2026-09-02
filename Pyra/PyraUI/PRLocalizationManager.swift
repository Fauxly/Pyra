//
//  PRLocalizationManager.swift
//  Pyra
//  Created by Fauxly on 06.07.2026.

import Foundation

enum PRLanguage: String {
    case russian = "ru"
    case english = "en"

    var displayName: String {
        switch self {
        case .russian: return "Русский"
        case .english: return "English"
        }
    }
}

/// Своя реализация выбора языка вместо переопределения UserDefaults "AppleLanguages" —
/// этот системный ключ на современных iOS/tvOS ненадёжен для программной смены языка
/// (Apple не гарантирует его учёт для конкретного приложения). Вместо этого просто
/// сами решаем, из какого .lproj брать строки, независимо от системного языка устройства.
enum PRLocalizationManager {

    private static let key = "PRSelectedLanguage"

    static var currentLanguage: PRLanguage {
        get {
            if let raw = UserDefaults.standard.string(forKey: key), let lang = PRLanguage(rawValue: raw) {
                return lang
            }
            // По умолчанию — язык системы, если он у нас поддерживается, иначе английский
            let systemCode = Locale.current.language.languageCode?.identifier ?? "en"
            return PRLanguage(rawValue: systemCode) ?? .english
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: key)
        }
    }

    static func bundle() -> Bundle {
        guard let path = Bundle.main.path(forResource: currentLanguage.rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return .main
        }
        return bundle
    }
}

extension String {
    var localized: String {
        // value: self — если ключ не найден в .strings, вернётся сам ключ, а не пустая строка,
        // так сразу видно на экране, что перевод забыли добавить, а не гадать почему пусто
        PRLocalizationManager.bundle().localizedString(forKey: self, value: self, table: nil)
    }
}
