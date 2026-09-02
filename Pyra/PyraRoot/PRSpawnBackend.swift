//
//  PRSpawnBackend.swift
//  Pyra
//
//  Created by Fix’s Trick’s on 07.07.2026.
//

import Foundation

public protocol PRSpawnBackend {
    /// elevated: если true — процесс запускается с persona-override на UID/GID 0 (root),
    /// через приватный posix_spawn persona API, а не через setuid-бинарники вроде tsu/su
    /// (которые на устройствах с nosuid-примонтированной "/" всё равно не сработают).
    func execute(binaryPath: String, arguments: [String], environment: [String]?, elevated: Bool) async throws -> PRSpawnResult
}
