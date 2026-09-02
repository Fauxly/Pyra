//
//  PRCategoriesViewController.swift
//  Pyra
//
//  Created by Fix’s Trick’s on 07.07.2026.
//

import UIKit

public final class PRCategoriesViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    private let tableView = UITableView(frame: .zero, style: .grouped)
    
    // Сюда прокидываем все пакеты
    public var allPackages: [PRPackage] = [] {
        didSet {
            updateCategories()
        }
    }
    
    // Список уникальных имен категорий
    private var categories: [String] = []
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = PRTheme.ink
        
        setupTableView()
    }
    
    private func setupTableView() {
        tableView.frame = view.bounds
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tableView.backgroundColor = .clear
        
        tableView.dataSource = self
        tableView.delegate = self
        
        // Регистрируем стандартную ячейку таблицы для tvOS
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "CategoryCell")
        
        view.addSubview(tableView)
    }
    
    private func updateCategories() {
        // Вытаскиваем уникальные секции, убираем пустые и сортируем по алфавиту
        let uniqueSections = Set(allPackages.map { $0.section })
        categories = uniqueSections.filter { !$0.isEmpty }.sorted()
        
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }
    
    // MARK: - UITableViewDataSource
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return categories.count
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CategoryCell", for: indexPath)
        cell.backgroundColor = .clear
        
        let categoryName = categories[indexPath.row]
        
        // Считаем сколько твиков находится в этой категории
        let count = allPackages.filter { $0.section == categoryName }.count
        
        // Фокусируемая ячейка получает фон через selectedBackgroundView, в тон теме
        let focusBackground = UIView()
        focusBackground.backgroundColor = PRTheme.surfaceFocused
        focusBackground.layer.cornerRadius = 8
        cell.selectedBackgroundView = focusBackground
        
        // Настраиваем текст в стиле tvOS
        if #available(tvOS 14.0, *) {
            var content = cell.defaultContentConfiguration()
            content.text = categoryName
            content.secondaryText = String(format: "CPREGORIES_PACKAGE_COUNT".localized, count)
            content.textProperties.color = PRTheme.textPrimary
            content.textProperties.font = UIFont.systemFont(ofSize: 28, weight: .medium)
            content.secondaryTextProperties.color = PRTheme.textSecondary
            content.secondaryTextProperties.font = UIFont.systemFont(ofSize: 22, weight: .regular)
            cell.contentConfiguration = content
        } else {
            cell.textLabel?.text = "\(categoryName) (\(count))"
            cell.textLabel?.textColor = PRTheme.textPrimary
            cell.textLabel?.font = UIFont.systemFont(ofSize: 28, weight: .medium)
        }
        
        return cell
    }
    
    // MARK: - UITableViewDelegate
    
    // tvOS для .grouped таблиц сам поднимает сфокусированную строку в виде светлой карточки
    // и наш selectedBackgroundView эту подложку не перекрывает — поэтому вместо борьбы с фоном
    // переключаем цвет текста: тёмный на фокусе (светлая карточка), светлый в состоянии покоя.
    public func tableView(_ tableView: UITableView, didUpdateFocusIn context: UITableViewFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        if let nextIndexPath = context.nextFocusedIndexPath,
           let cell = tableView.cellForRow(at: nextIndexPath) {
            coordinator.addCoordinatedAnimations({
                self.applyTextColor(to: cell, primary: PRTheme.ink, secondary: PRTheme.ink.withAlphaComponent(0.7))
            }, completion: nil)
        }
        
        if let previousIndexPath = context.previouslyFocusedIndexPath,
           let cell = tableView.cellForRow(at: previousIndexPath) {
            coordinator.addCoordinatedAnimations({
                self.applyTextColor(to: cell, primary: PRTheme.textPrimary, secondary: PRTheme.textSecondary)
            }, completion: nil)
        }
    }
    
    private func applyTextColor(to cell: UITableViewCell, primary: UIColor, secondary: UIColor) {
        if #available(tvOS 14.0, *), var content = cell.contentConfiguration as? UIListContentConfiguration {
            content.textProperties.color = primary
            content.secondaryTextProperties.color = secondary
            cell.contentConfiguration = content
        } else {
            cell.textLabel?.textColor = primary
            cell.detailTextLabel?.textColor = secondary
        }
    }
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let selectedCategory = categories[indexPath.row]
        
        // Фильтруем пакеты только для выбранной категории
        let filtered = allPackages.filter { $0.section == selectedCategory }
        
        // Для отображения отфильтрованных плиток используем наш готовый PRDashboardViewController,
        // просто передав ему имя категории в заголовок и отфильтрованный массив!
        let categoryDetailsVC = PRDashboardViewController()
        categoryDetailsVC.title = selectedCategory
        categoryDetailsVC.setCustomPackages(filtered)
        
        navigationController?.pushViewController(categoryDetailsVC, animated: true)
    }
    
    // Высота строки таблицы для комфортного выбора с пульта Apple TV
    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 90
    }
}
