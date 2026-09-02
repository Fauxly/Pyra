//
//  PRNetworkManager.swift
//  Pyra
//  Created by Fauxly on 06.07.2026.

import Foundation
import Compression

public class PRNetworkManager {

    public static let shared = PRNetworkManager()
    private let session: URLSession

    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 15.0
        self.session = URLSession(configuration: configuration)
    }

    public func fetchPackages(from repository: PRRepository) async throws -> [PRPackage] {
        // 1. Обычная вложенная структура (Procursus-style): dists/{arch}/{distribution}/{component}/binary-{arch}/Packages
        if let text = try await fetchPackagesText(url: repository.packagesURL) {
            return stamp(PRPackageParser().parse(text), with: repository)
        }
        if let text = try await fetchPackagesText(
            url: repository.packagesURL.appendingPathExtension("gz"),
            isGzip: true
        ) {
            return stamp(PRPackageParser().parse(text), with: repository)
        }

        // 2. "Плоский" формат (flat repository format) — Packages лежит прямо в корне репозитория,
        // без вложенности dists/. Многие маленькие самодельные репозитории (в том числе размещённые
        // прямо на GitHub Pages) устроены именно так.
        if let text = try await fetchPackagesText(url: repository.flatPackagesURL) {
            return stamp(PRPackageParser().parse(text), with: repository)
        }
        if let text = try await fetchPackagesText(
            url: repository.flatPackagesURL.appendingPathExtension("gz"),
            isGzip: true
        ) {
            return stamp(PRPackageParser().parse(text), with: repository)
        }

        throw NSError(
            domain: "PRNetworkManager",
            code: -4,
            userInfo: [NSLocalizedDescriptionKey: "ERROR_PACKAGES_NOT_FOUND".localized]
        )
    }

    /// Проставляет sourceRepository каждому распарсенному пакету — без этого карточка пакета
    /// не сможет собрать downloadURL (нужен baseURL репозитория, из которого пришёл пакет).
    private func stamp(_ packages: [PRPackage], with repository: PRRepository) -> [PRPackage] {
        packages.map { package in
            var stamped = package
            stamped.sourceRepository = repository
            return stamped
        }
    }

    /// Загружает файл Packages по указанному URL. Возвращает nil, если сервер отдал 404
    /// (в этом случае вызывающий код должен попробовать следующий вариант, например .gz),
    /// и бросает ошибку для остальных нештатных ситуаций.
    private func fetchPackagesText(url: URL, isGzip: Bool = false) async throws -> String? {

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        // Чистый профиль Apple TV OS 17
        request.setValue("Mozilla/5.0 (Apple TV; CPU OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 Pyra/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "PRNetworkManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "ERROR_NO_SERVER_RESPONSE".localized])
        }

        // 404 — не ошибка сама по себе, просто этого варианта файла нет на сервере
        if httpResponse.statusCode == 404 {
            return nil
        }

        guard httpResponse.statusCode == 200 else {
            throw NSError(domain: "PRNetworkManager", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: String(format: "ERROR_SERVER_STPRUS".localized, httpResponse.statusCode)])
        }

        let rawData: Data
        if isGzip {
            guard let decompressed = PRNetworkManager.gunzip(data) else {
                throw NSError(domain: "PRNetworkManager", code: -5, userInfo: [NSLocalizedDescriptionKey: "ERROR_GZIP_DECOMPRESS".localized])
            }
            rawData = decompressed
        } else {
            rawData = data
        }

        guard let rawPackagesText = String(data: rawData, encoding: .utf8) else {
            throw NSError(domain: "PRNetworkManager", code: -3, userInfo: [NSLocalizedDescriptionKey: "ERROR_UTF8_DECODE".localized])
        }

        return rawPackagesText
    }

    // MARK: - Gzip

    /// Распаковывает gzip-данные через Compression framework.
    /// Вручную снимает gzip-заголовок (с учётом переменных полей FEXTRA/FNAME/FCOMMENT/FHCRC)
    /// и 8-байтовый трейлер (CRC32 + ISIZE), затем декодирует "сырой" deflate-поток.
    static func gunzip(_ data: Data) -> Data? {
        // Минимальный валидный gzip: 10 байт заголовка + хотя бы пустой deflate-блок + 8 байт трейлера
        guard data.count > 18 else { return nil }

        let bytes = [UInt8](data)

        // Магические байты gzip: 0x1F 0x8B, метод сжатия должен быть 8 (deflate)
        guard bytes[0] == 0x1F, bytes[1] == 0x8B, bytes[2] == 0x08 else {
            return nil
        }

        let flags = bytes[3]
        var offset = 10

        // FEXTRA
        if flags & 0x04 != 0 {
            guard offset + 2 <= bytes.count else { return nil }
            let xlen = Int(bytes[offset]) | (Int(bytes[offset + 1]) << 8)
            offset += 2 + xlen
        }

        // FNAME (null-terminated строка)
        if flags & 0x08 != 0 {
            while offset < bytes.count, bytes[offset] != 0 { offset += 1 }
            offset += 1
        }

        // FCOMMENT (null-terminated строка)
        if flags & 0x10 != 0 {
            while offset < bytes.count, bytes[offset] != 0 { offset += 1 }
            offset += 1
        }

        // FHCRC (2 байта CRC16 заголовка)
        if flags & 0x02 != 0 {
            offset += 2
        }

        guard offset < bytes.count - 8 else { return nil }

        let deflateBytes = Array(bytes[offset..<(bytes.count - 8)])
        return decodeRawDeflate(deflateBytes)
    }

    /// Декодирует "сырой" deflate-поток (без zlib/gzip обёртки) через Compression framework,
    /// увеличивая буфер до тех пор, пока распакованные данные не перестанут упираться в его размер.
    private static func decodeRawDeflate(_ sourceBytes: [UInt8]) -> Data? {
        guard !sourceBytes.isEmpty else { return Data() }

        var capacity = max(sourceBytes.count * 20, 1 << 16)
        let maxCapacity = 1 << 30

        while capacity <= maxCapacity {
            var destination = [UInt8](repeating: 0, count: capacity)

            let decodedCount = destination.withUnsafeMutableBufferPointer { destPtr -> Int in
                sourceBytes.withUnsafeBufferPointer { srcPtr -> Int in
                    compression_decode_buffer(
                        destPtr.baseAddress!,
                        capacity,
                        srcPtr.baseAddress!,
                        sourceBytes.count,
                        nil,
                        COMPRESSION_ZLIB
                    )
                }
            }

            if decodedCount == 0 {
                capacity *= 2
                continue
            }

            if decodedCount == capacity {
                capacity *= 2
                continue
            }

            return Data(destination[0..<decodedCount])
        }

        return nil
    }
}
