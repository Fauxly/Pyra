//
//  PRCategoriesViewController.swift
//  Pyra
//
//  Created by Fauxly on 06.07.2026.
//

import UIKit

/// Категории — сетка цветных плиток: иконка категории, название, число пакетов
/// и превью иконок нескольких пакетов из неё. Нажатие — все пакеты категории плитками.
public final class PRCategoriesViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {

    private struct Category {
        let name: String
        let packages: [PRPackage]
    }

    private var collectionView: UICollectionView!
    private var categories: [Category] = []

    // Сюда прокидываем все пакеты
    public var allPackages: [PRPackage] = [] {
        didSet { updateCategories() }
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = PRTheme.ink

        let layout = UICollectionViewCompositionalLayout { _, _ in
            PRGridLayout.section(columns: 4, itemHeight: 230)
        }
        collectionView = PRGridLayout.makeCollectionView(in: view, layout: layout)
        collectionView.register(PRCategoryCell.self, forCellWithReuseIdentifier: PRCategoryCell.reuseIdentifier)
        collectionView.dataSource = self
        collectionView.delegate = self
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    private func updateCategories() {
        // Группируем по секции; пустые и "Unknown" не показываем. Сортировка — по числу
        // пакетов (самые наполненные категории первыми), при равенстве — по алфавиту.
        let grouped = Dictionary(grouping: allPackages) { $0.section.trimmingCharacters(in: .whitespaces) }
        categories = grouped
            .filter { !$0.key.isEmpty && $0.key.lowercased() != "unknown" }
            .map { Category(name: $0.key, packages: $0.value) }
            .sorted {
                $0.packages.count != $1.packages.count
                    ? $0.packages.count > $1.packages.count
                    : $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }

        DispatchQueue.main.async {
            self.collectionView?.reloadData()
        }
    }

    // MARK: - UICollectionViewDataSource

    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        categories.count
    }

    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PRCategoryCell.reuseIdentifier, for: indexPath) as? PRCategoryCell else {
            return UICollectionViewCell()
        }
        let category = categories[indexPath.item]
        let previews = category.packages.compactMap { $0.iconURL }.filter { !$0.isEmpty }
        cell.configure(name: category.name, count: category.packages.count, previewIconURLs: Array(previews.prefix(3)))
        return cell
    }

    // MARK: - UICollectionViewDelegate

    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let category = categories[indexPath.item]

        // Экран раздела: шапка в цвет категории + сетка пакетов, сгруппированная по источникам
        let categoryVC = PRPackageListViewController(mode: .category(name: category.name))
        categoryVC.setPackages(category.packages)
        navigationController?.pushViewController(categoryVC, animated: true)
    }
}
