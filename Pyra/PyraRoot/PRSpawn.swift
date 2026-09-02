//
//  PRSpawn.swift
//  Pyra
//
//  Created by Fix’s Trick’s on 07.07.2026.
//

import Foundation

public final class PRSpawn {

    private let backend: PRSpawnBackend

    public init(backend: PRSpawnBackend = PRPosixSpawnBackend()) {
        self.backend = backend
    }

    /// Выполнить команду асинхронно через экземпляр класса.
    /// elevated: true — запускает процесс от root через persona-override (см. PRSpawnBackend).
    public func run(binaryPath: String, arguments: [String], elevated: Bool = false) async throws -> PRSpawnResult {
        let correctedPath = PRPathManager.shared.makePath(binaryPath)
        return try await backend.execute(binaryPath: correctedPath, arguments: arguments, environment: nil, elevated: elevated)
    }

    /// Статический метод для вызовов напрямую вида PRSpawn.runCommand(...)
    public static func runCommand(_ binaryPath: String, arguments: [String] = [], elevated: Bool = false) async throws -> PRSpawnResult {
        let launcher = PRSpawn()
        return try await launcher.run(binaryPath: binaryPath, arguments: arguments, elevated: elevated)
    }
}
