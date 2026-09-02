//
//  PRPosixSpawnBackend.swift
//  Pyra
//
//  Created by Fix’s Trick’s on 07.07.2026.
//


import Foundation

// Публичные типы posix_spawn, скрытые в tvOS SDK
typealias SpawnFileActionsInit = @convention(c) (UnsafeMutablePointer<posix_spawn_file_actions_t?>?) -> Int32
typealias SpawnFileActionsDestroy = @convention(c) (UnsafeMutablePointer<posix_spawn_file_actions_t?>?) -> Int32
typealias SpawnFileActionsAddDup2 = @convention(c) (UnsafeMutablePointer<posix_spawn_file_actions_t?>?, Int32, Int32) -> Int32

typealias PosixSpawn = @convention(c) (
    UnsafeMutablePointer<pid_t>?,
    UnsafePointer<CChar>?,
    UnsafePointer<posix_spawn_file_actions_t?>?,
    UnsafePointer<posix_spawnattr_t?>?,
    UnsafePointer<UnsafeMutablePointer<CChar>?>?,
    UnsafePointer<UnsafeMutablePointer<CChar>?>?
) -> Int32

typealias SpawnAttrInit = @convention(c) (UnsafeMutablePointer<posix_spawnattr_t?>?) -> Int32
typealias SpawnAttrDestroy = @convention(c) (UnsafeMutablePointer<posix_spawnattr_t?>?) -> Int32

// Приватные persona-функции posix_spawn (недокументированный Darwin API).
// Именно через них PurePKG на этом же устройстве реально получает root — без setuid-бинарников
// вроде tsu/su, которые не работают на файловой системе, примонтированной с nosuid.
typealias SpawnAttrSetPersona = @convention(c) (UnsafeMutablePointer<posix_spawnattr_t?>?, uid_t, UInt32) -> Int32
typealias SpawnAttrSetPersonaUID = @convention(c) (UnsafeMutablePointer<posix_spawnattr_t?>?, uid_t) -> Int32
typealias SpawnAttrSetPersonaGID = @convention(c) (UnsafeMutablePointer<posix_spawnattr_t?>?, gid_t) -> Int32

// Значение флага из приватного заголовка spawn_internal.h (у Apple не документировано).
// Взято из рабочего кода PurePKG — если Apple когда-нибудь поменяет ABI, тут нужно будет свериться заново.
private let kPosixSpawnPersonaFlagsOverride: UInt32 = 1

public final class PRPosixSpawnBackend: PRSpawnBackend {

    public init() {}

    public func execute(binaryPath: String, arguments: [String], environment: [String]?, elevated: Bool) async throws -> PRSpawnResult {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<PRSpawnResult, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let result = try Self.executeSync(binaryPath: binaryPath, arguments: arguments, environment: environment, elevated: elevated)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Синхронная реализация (выполняется на фоновом потоке)

    private static func executeSync(binaryPath: String, arguments: [String], environment: [String]?, elevated: Bool) throws -> PRSpawnResult {

        guard FileManager.default.fileExists(atPath: binaryPath) else {
            throw PRSpawnError.binaryNotFound(path: binaryPath)
        }

        guard let handle = dlopen("/usr/lib/libSystem.dylib", RTLD_NOW) else {
            throw PRSpawnError.unknown(code: -10)
        }
        defer { dlclose(handle) }

        guard let symActionsInit = dlsym(handle, "posix_spawn_file_actions_init"),
              let symActionsDestroy = dlsym(handle, "posix_spawn_file_actions_destroy"),
              let symAddDup2 = dlsym(handle, "posix_spawn_file_actions_adddup2"),
              let symSpawn = dlsym(handle, "posix_spawn"),
              let symAttrInit = dlsym(handle, "posix_spawnattr_init"),
              let symAttrDestroy = dlsym(handle, "posix_spawnattr_destroy") else {
            throw PRSpawnError.unknown(code: -11)
        }

        let sysActionsInit = unsafeBitCast(symActionsInit, to: SpawnFileActionsInit.self)
        let sysActionsDestroy = unsafeBitCast(symActionsDestroy, to: SpawnFileActionsDestroy.self)
        let sysAddDup2 = unsafeBitCast(symAddDup2, to: SpawnFileActionsAddDup2.self)
        let sysSpawn = unsafeBitCast(symSpawn, to: PosixSpawn.self)
        let sysAttrInit = unsafeBitCast(symAttrInit, to: SpawnAttrInit.self)
        let sysAttrDestroy = unsafeBitCast(symAttrDestroy, to: SpawnAttrDestroy.self)

        // persona-функции нужны только для elevated-запуска — резолвим лениво,
        // чтобы обычные (неэлевейтед) вызовы не зависели от наличия этого приватного API
        var sysSetPersona: SpawnAttrSetPersona?
        var sysSetPersonaUID: SpawnAttrSetPersonaUID?
        var sysSetPersonaGID: SpawnAttrSetPersonaGID?

        if elevated {
            guard let symSetPersona = dlsym(handle, "posix_spawnattr_set_persona_np"),
                  let symSetPersonaUID = dlsym(handle, "posix_spawnattr_set_persona_uid_np"),
                  let symSetPersonaGID = dlsym(handle, "posix_spawnattr_set_persona_gid_np") else {
                throw PRSpawnError.unknown(code: -12)
            }
            sysSetPersona = unsafeBitCast(symSetPersona, to: SpawnAttrSetPersona.self)
            sysSetPersonaUID = unsafeBitCast(symSetPersonaUID, to: SpawnAttrSetPersonaUID.self)
            sysSetPersonaGID = unsafeBitCast(symSetPersonaGID, to: SpawnAttrSetPersonaGID.self)
        }

        var stdoutPipe: [Int32] = [-1, -1]
        var stderrPipe: [Int32] = [-1, -1]

        func safeClose(_ fd: inout Int32) {
            if fd >= 0 {
                close(fd)
                fd = -1
            }
        }

        defer {
            safeClose(&stdoutPipe[0]); safeClose(&stdoutPipe[1])
            safeClose(&stderrPipe[0]); safeClose(&stderrPipe[1])
        }

        guard pipe(&stdoutPipe) == 0, pipe(&stderrPipe) == 0 else {
            throw PRSpawnError.pipeCreationFailed
        }

        var actions: posix_spawn_file_actions_t?
        _ = sysActionsInit(&actions)
        defer { _ = sysActionsDestroy(&actions) }

        _ = sysAddDup2(&actions, stdoutPipe[1], STDOUT_FILENO)
        _ = sysAddDup2(&actions, stderrPipe[1], STDERR_FILENO)

        var attr: posix_spawnattr_t?
        _ = sysAttrInit(&attr)
        defer { _ = sysAttrDestroy(&attr) }

        if elevated {
            // persona_id тут — заглушка (99), реальный эффект дают override-флаг + explicit
            // uid/gid ниже, которые принудительно выставляют root вне зависимости от persona_id.
            // Это то же самое сочетание вызовов, которое использует PurePKG на этом устройстве.
            _ = sysSetPersona?(&attr, 99, kPosixSpawnPersonaFlagsOverride)
            _ = sysSetPersonaUID?(&attr, 0)
            _ = sysSetPersonaGID?(&attr, 0)
        }

        let allArgs = [binaryPath] + arguments
        var cArgs = allArgs.map { strdup($0) }
        cArgs.append(nil)
        defer { cArgs.forEach { if let ptr = $0 { free(ptr) } } }

        // Без одинарных кавычек в значении PATH — они не нужны, posix_spawn не проходит через shell,
        // и кавычки попали бы в переменную окружения буквально как символы (баг, который есть в PurePKG).
        let defaultEnv = environment ?? [
            "PATH=/usr/bin:/usr/local/bin:/bin:/usr/sbin:/var/jb/usr/bin:/var/jb/usr/local/bin:/var/jb/bin:/var/jb/usr/sbin"
        ]
        var cEnvs = defaultEnv.map { strdup($0) }
        cEnvs.append(nil)
        defer { cEnvs.forEach { if let ptr = $0 { free(ptr) } } }

        var pid: pid_t = 0
        let status = sysSpawn(&pid, binaryPath, &actions, &attr, cArgs, cEnvs)

        guard status == 0 else {
            throw PRSpawnError.unknown(code: status)
        }

        safeClose(&stdoutPipe[1])
        safeClose(&stderrPipe[1])

        let readGroup = DispatchGroup()
        var stdoutData = Data()
        var stderrData = Data()

        readGroup.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            stdoutData = readData(from: stdoutPipe[0])
            readGroup.leave()
        }

        readGroup.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            stderrData = readData(from: stderrPipe[0])
            readGroup.leave()
        }

        readGroup.wait()

        var exitStatus: Int32 = 0
        waitpid(pid, &exitStatus, 0)

        let finalExitCode: Int32
        var stderrString = String(data: stderrData, encoding: .utf8) ?? ""

        if (exitStatus & 0x7f) == 0 {
            finalExitCode = (exitStatus >> 8) & 0xFF
        } else {
            let signal = exitStatus & 0x7f
            finalExitCode = 128 + signal
            stderrString += "\n[Pyra] Процесс был прерван сигналом \(signal), не завершился штатно"
        }

        let stdoutString = String(data: stdoutData, encoding: .utf8) ?? ""

        return PRSpawnResult(exitCode: finalExitCode, stdout: stdoutString, stderr: stderrString)
    }

    private static func readData(from fd: Int32) -> Data {
        var data = Data()
        let bufferSize = 4096
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        while true {
            let bytesRead = read(fd, buffer, bufferSize)
            if bytesRead <= 0 { break }
            data.append(buffer, count: bytesRead)
        }
        return data
    }
}
