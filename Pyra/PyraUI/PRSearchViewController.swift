//
//  PRSearchViewController.swift
//  Pyra
//
//  Created by Fauxly on 06.07.2026.
//
import UIKit

public final class PRSearchViewController: UIViewController, UISearchResultsUpdating {
    
    // Создаем отдельный контроллер результатов
    private let resultsVC = PRSearchResultsViewController()
    
    public var allPackages: [PRPackage] = [] {
        didSet {
            // Передаем полную базу пакетов в контроллер результатов сразу при загрузке
            resultsVC.allPackages = allPackages
        }
    }
    
    public lazy var searchController: UISearchController = {
        // Передаем контроллер результатов в системный инициализатор
        let search = UISearchController(searchResultsController: resultsVC)
        search.searchResultsUpdater = self
        search.obscuresBackgroundDuringPresentation = false
        search.hidesNavigationBarDuringPresentation = false
        
        search.searchBar.placeholder = "SEARCH_PLACEHOLDER".localized
        search.searchBar.tintColor = PRTheme.brass
        return search
    }()
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = PRTheme.ink
        
        // Встраиваем поисковую панель прямо в иерархию интерфейса
        let searchContainer = UISearchContainerViewController(searchController: searchController)
        addChild(searchContainer)
        searchContainer.view.frame = view.bounds
        view.addSubview(searchContainer.view)
        searchContainer.didMove(toParent: self)
    }
    
    // MARK: - UISearchResultsUpdating
    
    public func updateSearchResults(for searchController: UISearchController) {
        guard let searchText = searchController.searchBar.text?.lowercased(), !searchText.isEmpty else {
            // Если строка пустая — очищаем результаты или показываем все
            resultsVC.updateResults(with: [])
            return
        }
        
        // Фильтруем
        let filtered = allPackages.filter { package in
            package.name.lowercased().contains(searchText) ||
            package.packageID.lowercased().contains(searchText)
        }
        
        // Принудительно отправляем отфильтрованный массив в сетку
        resultsVC.updateResults(with: filtered)
    }
}
