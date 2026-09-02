//  Created by Fauxly on 06.07.2026.

import Foundation

public struct PRPackage: Identifiable {
    /// Уникальный идентификатор для соответствия протоколу Identifiable (использует packageID)
    public var id: String { packageID }
    
    // Классические поля Control-файла любого джейлбрейк-пакета
    public var packageID: String       // Пример: com.fixstricks.atvvolume
    public var name: String            // Название: ATV Volume HUD Customize
    public var version: String         // Версия: 1.0.4
    public var architecture: String    // Архитектура: appletvos-arm64
    public var description: String     // Описание возможностей твика
    public var filename: String        // Относительный путь к .deb файлу на сервере репозитория
    public var section: String         // Категория (Tweaks, Launchers, Утилиты)
    
    // Опциональные поля
    public var author: String?         // Автор/Разработчик твика
    public var depends: String?        // Зависимости (например: firmware (>= 15.0), mobilesubstrate)
    public var iconURL: String?        // Прямая ссылка на иконку твика для отображения в сетке
    
    /// Репозиторий, из которого этот пакет был загружен — проставляется в PRNetworkManager
    /// сразу после парсинга Packages. Нужен, чтобы карточка пакета (PRPackageDetailsViewController)
    /// знала, откуда качать сам .deb (downloadURL строится от baseURL репозитория), не тягая
    /// PRRepository отдельным параметром через каждый push по цепочке экранов.
    public var sourceRepository: PRRepository?
    
    /// Публичный инициализатор со всеми параметрами и дефолтными значениями для удобства
    public init(
        packageID: String,
        name: String,
        version: String,
        architecture: String = "appletvos-arm64",
        description: String = "",
        filename: String = "",
        section: String = "Unknown",
        author: String? = nil,
        depends: String? = nil,
        iconURL: String? = nil,
        sourceRepository: PRRepository? = nil
    ) {
        self.packageID = packageID
        self.name = name
        self.version = version
        self.architecture = architecture
        self.description = description
        self.filename = filename
        self.section = section
        self.author = author
        self.depends = depends
        self.iconURL = iconURL
        self.sourceRepository = sourceRepository
    }
}
