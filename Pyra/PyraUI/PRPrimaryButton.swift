//
//  PRPrimaryButton.swift
//  Pyra
//
//  Created by Fix’s Trick’s on 06.07.2026.
//

//
//  PRPrimaryButton.swift
//  Pyra
//

import UIKit

final class PRPrimaryButton: UIButton {

    override init(frame: CGRect) {
        super.init(frame: frame)

        translatesAutoresizingMaskIntoConstraints = false

        backgroundColor = .systemBlue
        tintColor = .white

        layer.cornerRadius = 18
        clipsToBounds = true

        titleLabel?.font = .systemFont(ofSize: 34, weight: .bold)

        setTitleColor(.white, for: .normal)

        adjustsImageWhenHighlighted = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didUpdateFocus(
        in context: UIFocusUpdateContext,
        with coordinator: UIFocusAnimationCoordinator
    ) {

        super.didUpdateFocus(in: context, with: coordinator)

        coordinator.addCoordinatedAnimations({

            if self.isFocused {

                self.transform = CGAffineTransform(scaleX: 1.08, y: 1.08)
                self.backgroundColor = .systemGreen

            } else {

                self.transform = .identity
                self.backgroundColor = .systemBlue
            }

        })
    }
}
