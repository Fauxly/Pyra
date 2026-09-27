//
//  PRGridLayout.swift
//  Pyra
//  Created by Fauxly on 27.09.2026.

import UIKit

/// Общая сетка для вкладок: N колонок фиксированной высоты, одинаковые отступы по краям
/// (в тон главной) и опциональный заголовок секции.
enum PRGridLayout {

    static let horizontalInset: CGFloat = 60

    static func section(columns: Int,
                        itemHeight: CGFloat,
                        spacing: CGFloat = 36,
                        header: Bool = false,
                        topInset: CGFloat = 20,
                        bottomInset: CGFloat = 40) -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0 / CGFloat(columns)),
                                              heightDimension: .fractionalHeight(1.0))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: spacing / 2, bottom: 0, trailing: spacing / 2)

        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                               heightDimension: .absolute(itemHeight))
        // subitems-массив, а не repeatingSubitem:count: — тот есть только с tvOS 16
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize,
                                                       subitems: Array(repeating: item, count: columns))

        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = spacing
        section.contentInsets = NSDirectionalEdgeInsets(top: topInset,
                                                        leading: horizontalInset - spacing / 2,
                                                        bottom: bottomInset,
                                                        trailing: horizontalInset - spacing / 2)
        if header {
            let headerItem = NSCollectionLayoutBoundarySupplementaryItem(
                layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(70)),
                elementKind: UICollectionView.elementKindSectionHeader,
                alignment: .top
            )
            section.boundarySupplementaryItems = [headerItem]
        }
        return section
    }

    static func makeCollectionView(in view: UIView, layout: UICollectionViewLayout) -> UICollectionView {
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.remembersLastFocusedIndexPath = true
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)
        return collectionView
    }
}
