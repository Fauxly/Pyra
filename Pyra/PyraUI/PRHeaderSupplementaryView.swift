//
//  PRHeaderSupplementaryView.swift
//  Pyra
//
//  Created by Fix’s Trick’s on 07.07.2026.
//

import UIKit

public final class PRHeaderSupplementaryView: UICollectionReusableView {
    
    public let titleLabel = UILabel()
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        
        titleLabel.textColor = .white
        titleLabel.font = UIFont.systemFont(ofSize: 36, weight: .bold) // Нативный размер для tvOS
        titleLabel.frame = bounds // Текст занимает ровно выделенное под него пространство
        titleLabel.textAlignment = .left
        
        addSubview(titleLabel)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
