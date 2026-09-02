//
//  PRSearchResultsViewController.swift
//  Pyra
//
//  Created by Fauxly on 06.07.2026.
//

import UIKit

public final class PRSearchResultsViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {
    
    private var collectionView: UICollectionView!
    
    public var allPackages: [PRPackage] = []
    private var filteredPackages: [PRPackage] = []
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = PRTheme.ink
        
        setupCollectionView()
    }
    
    private func setupCollectionView() {
        let layout = createLayout()
        
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = .clear
        
        collectionView.register(PRPackageCell.self, forCellWithReuseIdentifier: PRPackageCell.reuseIdentifier)
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.remembersLastFocusedIndexPath = true
        
        view.addSubview(collectionView)
    }
    
    private func createLayout() -> UICollectionViewLayout {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.2),
                                              heightDimension: .fractionalHeight(1.0))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: 15, leading: 20, bottom: 15, trailing: 20)
        
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                               heightDimension: .absolute(340))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
        
        let section = NSCollectionLayoutSection(group: group)
        // Отрегулированный отступ сверху, чтобы сетка не перекрывала клавиатуру ввода tvOS
        section.contentInsets = NSDirectionalEdgeInsets(top: 150, leading: 0, bottom: 40, trailing: 0)
        
        return UICollectionViewCompositionalLayout(section: section)
    }
    
    public func updateResults(with packages: [PRPackage]) {
        self.filteredPackages = packages
        if collectionView != nil {
            collectionView.reloadData()
        }
    }
    
    // MARK: - UICollectionViewDataSource
    
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return filteredPackages.count
    }
    
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PRPackageCell.reuseIdentifier, for: indexPath) as? PRPackageCell else {
            return UICollectionViewCell()
        }
        cell.configure(with: filteredPackages[indexPath.item])
        return cell
    }
    
    // MARK: - UICollectionViewDelegate
    
    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let package = filteredPackages[indexPath.item]
        let detailsVC = PRPackageDetailsViewController(package: package)
        
        // Самый надежный способ пуша на tvOS внутри UISearchContainer:
        // Ищем родительский навигационный контроллер, в котором лежит сам поиск
        if let nav = self.parent?.navigationController {
            nav.pushViewController(detailsVC, animated: true)
        } else if let presentingNav = self.presentingViewController?.navigationController {
            presentingNav.pushViewController(detailsVC, animated: true)
        } else {
            // Резервный вариант, если навигация заблокирована системой
            let navWrapper = UINavigationController(rootViewController: detailsVC)
            present(navWrapper, animated: true, completion: nil)
        }
    }
}
