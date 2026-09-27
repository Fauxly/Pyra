//
//  PRCategoryStyle.swift
//  Pyra
//  Created by Fauxly on 27.09.2026.

import UIKit

/// Иконка и цвет для категории (поле Section). У популярных категорий — осмысленная
/// иконка; неизвестные получают нейтральную, а цвет подбирается по хэшу названия —
/// стабильно, чтобы одна и та же категория всегда была одного цвета.
enum PRCategoryStyle {

    struct Style {
        let symbol: String
        let color: UIColor
    }

    private static let palette: [UIColor] = [
        PRTheme.brass,
        PRTheme.teal,
        UIColor(red: 0x9D / 255, green: 0x8F / 255, blue: 0xE0 / 255, alpha: 1), // лаванда
        UIColor(red: 0xE0 / 255, green: 0x8A / 255, blue: 0x7A / 255, alpha: 1), // коралл
        UIColor(red: 0x7F / 255, green: 0xB0 / 255, blue: 0xE8 / 255, alpha: 1), // голубой
        UIColor(red: 0x9C / 255, green: 0xC4 / 255, blue: 0x6E / 255, alpha: 1), // оливковый
        UIColor(red: 0xD9 / 255, green: 0x8C / 255, blue: 0xB3 / 255, alpha: 1)  // розовый
    ]

    /// Ключевые слова → (иконка, индекс цвета в палитре). Проверяются по вхождению
    /// в название в нижнем регистре, первое совпадение побеждает.
    private static let rules: [(keywords: [String], symbol: String, color: Int)] = [
        (["tweak"], "wand.and.stars", 0),
        (["theme", "appearance", "wallpaper"], "paintpalette", 6),
        (["util", "tool"], "wrench.and.screwdriver", 2),
        (["terminal", "shell"], "terminal", 3),
        (["network", "vpn", "proxy"], "network", 4),
        (["system", "admin"], "gearshape.2", 1),
        (["packag", "repo"], "shippingbox", 0),
        (["develop", "sdk", "debug"], "hammer", 3),
        (["librar", "framework", "depend"], "books.vertical", 5),
        (["game", "emulat"], "gamecontroller", 6),
        (["media", "video", "stream", "tv"], "play.rectangle", 4),
        (["app"], "square.grid.3x3", 1),
        (["secur", "crypt"], "lock.shield", 5),
        (["text", "edit"], "doc.text", 2),
        (["archiv", "compress"], "archivebox", 5),
        (["data"], "cylinder.split.1x2", 4)
    ]

    static func style(for category: String) -> Style {
        let lower = category.lowercased()
        for rule in rules where rule.keywords.contains(where: { lower.contains($0) }) {
            return Style(symbol: rule.symbol, color: palette[rule.color])
        }
        // Стабильный хэш (String.hashValue меняется между запусками — не годится)
        let hash = lower.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0x7fffffff }
        return Style(symbol: "square.grid.2x2", color: palette[hash % palette.count])
    }
}
