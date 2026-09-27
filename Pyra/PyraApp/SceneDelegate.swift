//
//  SceneDelegate.swift
//  Pyra
//  Created by Fauxly on 06.07.2026.


import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        let root = PRCustomTabBarController()
        window.rootViewController = root
        window.makeKeyAndVisible()
        self.window = window

        // Холодный старт по ссылке — например, выбор пакета на верхней полке
        if let url = connectionOptions.urlContexts.first?.url {
            handle(url)
        }
    }

    /// Ссылка пришла, когда приложение уже запущено
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        if let url = URLContexts.first?.url {
            handle(url)
        }
    }

    /// pyra://package/<packageID> → карточка пакета
    private func handle(_ url: URL) {
        guard url.scheme?.lowercased() == "pyra",
              url.host?.lowercased() == "package",
              let rawID = url.pathComponents.dropFirst().first,
              let root = window?.rootViewController as? PRCustomTabBarController else { return }

        let packageID = rawID.removingPercentEncoding ?? rawID
        root.openPackage(withID: packageID)
    }
}
