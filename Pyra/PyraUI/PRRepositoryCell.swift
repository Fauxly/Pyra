//
//  PRRepositoryCell.swift
//  Pyra
//

import UIKit

final class PRRepositoryCell: UITableViewCell {

    static let reuseIdentifier = "PRRepositoryCell"

    private let progressTrack = UIView()
    private let progressFill = UIView()
    private var progressAnimationRunning = false

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupProgressBar()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupProgressBar()
    }

    private func setupProgressBar() {
        progressTrack.backgroundColor = PRTheme.ink
        progressTrack.layer.cornerRadius = 2
        progressTrack.clipsToBounds = true
        progressTrack.isHidden = true
        progressTrack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(progressTrack)

        progressFill.backgroundColor = PRTheme.brass
        progressTrack.addSubview(progressFill)

        NSLayoutConstraint.activate([
            progressTrack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            progressTrack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            progressTrack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
            progressTrack.heightAnchor.constraint(equalToConstant: 4)
        ])
    }

    /// Показывает/скрывает и запускает/останавливает мини-полосу прогресса на ЭТОЙ конкретной
    /// строке — независимо от общей полосы наверху экрана, которая просто говорит "что-то грузится",
    /// а эта — "именно этот репозиторий ещё грузится".
    func setLoading(_ loading: Bool) {
        progressTrack.isHidden = !loading
        if loading {
            startAnimation()
        } else {
            stopAnimation()
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        stopAnimation()
        progressTrack.isHidden = true
    }

    private func startAnimation() {
        guard !progressAnimationRunning else { return }
        progressAnimationRunning = true
        progressTrack.layoutIfNeeded()
        animatePass()
    }

    private func animatePass() {
        guard progressAnimationRunning else { return }

        let trackWidth = progressTrack.bounds.width
        guard trackWidth > 0 else {
            // Layout ещё не прошёл — попробуем на следующем цикле раннлупа
            DispatchQueue.main.async { [weak self] in
                self?.animatePass()
            }
            return
        }

        let fillWidth = max(trackWidth * 0.3, 30)
        progressFill.frame = CGRect(x: -fillWidth, y: 0, width: fillWidth, height: 4)

        UIView.animate(
            withDuration: 0.9,
            delay: 0,
            options: [.curveEaseInOut],
            animations: {
                self.progressFill.frame = CGRect(x: trackWidth, y: 0, width: fillWidth, height: 4)
            },
            completion: { [weak self] _ in
                guard let self, self.progressAnimationRunning else { return }
                self.animatePass()
            }
        )
    }

    private func stopAnimation() {
        progressAnimationRunning = false
        progressFill.layer.removeAllAnimations()
    }
}
