//
//  PRAppSettings.swift
//  Pyra
//  Created by Fauxly on 06.07.2026.

import Foundation

enum PRAppSettings {

    private static let autoUpdateKey = "PRAutoUpdateOnLaunch"

    /// По умолчанию включено — сохраняем прежнее поведение для тех, кто ничего не менял
    static var autoUpdateOnLaunch: Bool {
        get {
            if UserDefaults.standard.object(forKey: autoUpdateKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: autoUpdateKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: autoUpdateKey)
        }
    }
}
