//
//  PRInstalledPackage.swift
//  Pyra
//
//  Created by Fix’s Trick’s on 08.07.2026.
//

import Foundation

public struct PRInstalledPackage {
    public let id: String
    public let name: String
    public let version: String
    public let description: String
    public let section: String
    /// Installed-Size из dpkg status, в килобайтах; у части пакетов поля нет
    public var installedSizeKB: Int64? = nil
}
