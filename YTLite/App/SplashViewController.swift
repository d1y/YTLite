import UIKit

final class SplashViewController: UIViewController {
    var onComplete: (() -> Void)?

    private let logoView = UIImageView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ThemeManager.shared.background
        setupUI()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        animateAndComplete()
    }

    // MARK: - UI

    private func setupUI() {
        logoView.image = UIImage(named: "LaunchLogo")
        logoView.contentMode = .scaleAspectFit
        logoView.translatesAutoresizingMaskIntoConstraints = false
        logoView.alpha = 0
        view.addSubview(logoView)

        NSLayoutConstraint.activate([
            logoView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            logoView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            logoView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.15),
            logoView.heightAnchor.constraint(equalTo: logoView.widthAnchor, multiplier: 0.7)
        ])
    }

    // MARK: - Animation

    private func animateAndComplete() {
        // Skills: enter from scale 0.95 + opacity (never scale 0); ease-out.
        logoView.transform = CGAffineTransform(
            scaleX: MotionStyle.enterScale,
            y: MotionStyle.enterScale
        )
        MotionStyle.animateChrome(duration: MotionStyle.chromeDuration) {
            self.logoView.alpha = 1
            self.logoView.transform = .identity
        } completion: { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                MotionStyle.animateChrome(duration: MotionStyle.chromeDuration) {
                    self.logoView.alpha = 0
                    self.logoView.transform = CGAffineTransform(
                        scaleX: MotionStyle.enterScale,
                        y: MotionStyle.enterScale
                    )
                } completion: { _ in
                    self.onComplete?()
                }
            }
        }
    }
}
