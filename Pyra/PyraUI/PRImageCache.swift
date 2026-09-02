//
//  PRImageCache.swift
//  Pyra
//
//  Created by Fix’s Trick’s on 09.07.2026.
//

//
//  PRImageCache.swift
//  Pyra
//

import UIKit

/// Простой in-memory кэш иконок твиков. NSCache сам разгружается под давлением памяти,
/// поэтому отдельно чистить его руками не нужно.
public final class PRImageCache {

    public static let shared = PRImageCache()

    private let cache = NSCache<NSString, UIImage>()
    private let session: URLSession

    private init() {
        cache.countLimit = 500

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 10
        self.session = URLSession(configuration: configuration)
    }

    /// Возвращает картинку из кэша, либо скачивает и кладёт в кэш.
    /// Возвращает nil при любой ошибке (битый URL, таймаут, не изображение) —
    /// вызывающая сторона в этом случае просто оставляет плейсхолдер.
    public func image(for urlString: String) async -> UIImage? {
        let key = urlString as NSString

        if let cached = cache.object(forKey: key) {
            return cached
        }

        guard let url = URL(string: urlString) else { return nil }

        do {
            let (data, response) = try await session.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let image = UIImage(data: data) else {
                return nil
            }

            cache.setObject(image, forKey: key)
            return image
        } catch {
            return nil
        }
    }
}
