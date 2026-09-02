//
//  PRAppearance.swift
//  Pyra
//

import UIKit

/// Глобальная тема через UIAppearance-прокси. Красит системный "хром" (навбар, таббар,
/// поисковую строку, разделители таблиц) во всём приложении одним местом, без правки
/// каждого экрана вручную. Вызвать один раз при старте — из AppDelegate/SceneDelegate,
/// например в application(_:didFinishLaunchingWithOptions:) или scene(_:willConnectTo:options:),
/// до создания любых view controller'ов.
enum PRAppearance {

    static func apply() {
        // Общий tint — латунный акцент на кнопках, курсоре поиска, выделении и т.д.
        UIWindow.appearance().tintColor = PRTheme.brass

        configureTabBar()
        configureNavigationBar()
        configureTableView()
        configureSearchBar()
    }

    private static func configureTabBar() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = PRTheme.ink

        let normal = appearance.stackedLayoutAppearance.normal
        normal.iconColor = PRTheme.textSecondary
        normal.titleTextAttributes = [.foregroundColor: PRTheme.textSecondary]

        let selected = appearance.stackedLayoutAppearance.selected
        selected.iconColor = PRTheme.brass
        selected.titleTextAttributes = [.foregroundColor: PRTheme.brass]

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().tintColor = PRTheme.brass
        UITabBar.appearance().unselectedItemTintColor = PRTheme.textSecondary
        #if os(iOS)
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
        #endif
    }

    private static func configureNavigationBar() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = PRTheme.ink
        appearance.titleTextAttributes = [.foregroundColor: PRTheme.textPrimary]
        appearance.largeTitleTextAttributes = [.foregroundColor: PRTheme.textPrimary]

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().tintColor = PRTheme.brass
    }

    private static func configureTableView() {
        UITableView.appearance().backgroundColor = PRTheme.ink
    }

    private static func configureSearchBar() {
        UISearchBar.appearance().tintColor = PRTheme.brass
        UISearchBar.appearance().barTintColor = PRTheme.ink
        UITextField.appearance(whenContainedInInstancesOf: [UISearchBar.self]).textColor = PRTheme.textPrimary
    }
}
