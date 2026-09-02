//
//  PRSpawnResult.swift
//  Pyra
//
//  Created by Fix’s Trick’s on 07.07.2026.
//

import Foundation

public struct PRSpawnResult {
    /// Код завершения процесса (0 — успех)
    public let exitCode: Int32
    
    /// Текстовый вывод консоли (Стандартный вывод)
    public let stdout: String
    
    /// Логи ошибок консоли (Стандартный вывод ошибок)
    public let stderr: String
    
    /// Дополнительное свойство-мост для совместимости с твоим UI-слоем
    public var output: String {
        return stdout
    }
}
