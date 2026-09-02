//
//  PRSpawnError.swift
//  Pyra
//
//  Created by Fix’s Trick’s on 07.07.2026.
//

import Foundation

public enum PRSpawnError: Error, LocalizedError {
    case binaryNotFound(path: String)
    case permissionDenied(path: String)
    case pipeCreationFailed
    case unknown(code: Int32)
    
    public var errorDescription: String? {
        switch self {
        case .binaryNotFound(let path):
            return "Исполняемый файл не найден по пути: \(path)"
        case .permissionDenied(let path):
            return "Отказано в доступе (права POSIX) для файла: \(path)"
        case .pipeCreationFailed:
            return "Не удалось создать системные дескрипторы (Pipes) для перехвата логов"
        case .unknown(let code):
            return "Системная ошибка POSIX spawn с кодом: \(code)"
        }
    }
}
