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
        window.rootViewController = PRCustomTabBarController()
        window.makeKeyAndVisible()
        self.window = window
    }
}
