//
//  PRTheme.swift
//  Pyra
//  Created by Fauxly on 06.07.2026.

import UIKit

/// Палитра приложения: тёмная "чернильная" тема с латунным акцентом —
/// в духе старых атласов и навигационных приборов, а не дежурный чёрный фон + серый хайлайт.
enum PRTheme {

    /// Фон экранов — тёплый тёмно-синий вместо плоского чёрного
    static let ink = UIColor(red: 0x12 / 255, green: 0x14 / 255, blue: 0x1C / 255, alpha: 1)

    /// Карточка твика в состоянии покоя
    static let surface = UIColor(red: 0x1C / 255, green: 0x20 / 255, blue: 0x30 / 255, alpha: 1)

    /// Карточка твика в фокусе
    static let surfaceFocused = UIColor(red: 0x26 / 255, green: 0x2B / 255, blue: 0x40 / 255, alpha: 1)

    /// Латунный акцент — главный сигнатурный элемент темы (кольцо фокуса, ключевые CTA)
    static let brass = UIColor(red: 0xC9 / 255, green: 0xA1 / 255, blue: 0x5C / 255, alpha: 1)

    /// Вторичный акцент — для тегов категорий, второстепенных элементов
    static let teal = UIColor(red: 0x4F / 255, green: 0xA9 / 255, blue: 0xA8 / 255, alpha: 1)

    /// Основной текст — тёплый "пергаментный" оттенок вместо чистого белого
    static let textPrimary = UIColor(red: 0xF4 / 255, green: 0xEF / 255, blue: 0xE4 / 255, alpha: 1)

    /// Второстепенный текст (версии, описания)
    static let textSecondary = UIColor(red: 0x9A / 255, green: 0xA0 / 255, blue: 0xB4 / 255, alpha: 1)
}
