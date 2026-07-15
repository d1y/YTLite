import UIKit
import SafariServices

final class AuthViewController: UIViewController {
    var onAuthorized: (() -> Void)?
    var onContinueAnonymously: (() -> Void)?

    private let titleLabel = UILabel()
    private let instructionLabel = UILabel()
    private let codeChip = DeviceCodeChipView()
    private let statusLabel = UILabel()
    private let openButton = HoverFillButton(type: .system)
    private let retryButton = HoverFillButton(type: .system)
    private let anonymousButton = UIButton(type: .system)
    private let spinner: UIActivityIndicatorView = {
        if #available(iOS 13.0, *) {
            return UIActivityIndicatorView(style: .medium)
        }
        return UIActivityIndicatorView(style: .white)
    }()

    private var verificationURL: URL?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupUI()
        startAuth()
    }

    private func setupUI() {
        configureLabels()
        configureButtons()
        configureSpinner()
        addControlSubviews()
        layoutTitleAndCode()
        layoutButtonsAndStatus()
    }

    @objc
    private func openVerificationURL() {
        guard let url = verificationURL else {
            return
        }
        if let code = codeChip.code {
            UIPasteboard.general.string = code
        }
        // Brief status feedback after click.
        let previous = statusLabel.text
        statusLabel.textColor = UIColor(white: 0.75, alpha: 1)
        statusLabel.text = "Code copied · Opening browser…"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self, self.verificationURL != nil else { return }
            self.statusLabel.textColor = .lightGray
            self.statusLabel.text = previous ?? "Waiting for authorization..."
        }
        // On Mac, SFSafariViewController is awkward — open the system browser.
        if PlatformStyle.isMac {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
            return
        }
        let safari = SFSafariViewController(url: url)
        present(safari, animated: true)
    }

    @objc
    private func retrySignIn() {
        retryButton.isHidden = true
        openButton.isHidden = true
        codeChip.code = nil
        statusLabel.text = "Connecting to YouTube…"
        statusLabel.textColor = .lightGray
        spinner.startAnimating()
        startAuth()
    }

    @objc
    private func continueAnonymously() {
        OAuthClient.shared.isAnonymous = true
        if let cb = onContinueAnonymously {
            cb()
        } else {
            onAuthorized?()
        }
    }
}

// MARK: - Configuration
private extension AuthViewController {
    func configureLabels() {
        titleLabel.text = "Sign in to YouTube"
        titleLabel.textColor = .white
        titleLabel.font = UIFont.boldSystemFont(ofSize: 22)
        titleLabel.textAlignment = .center

        instructionLabel.text = "Click the code to copy, then open the link"
            + " and paste it on the page."
        instructionLabel.textColor = .lightGray
        instructionLabel.font = UIFont.systemFont(ofSize: 15)
        instructionLabel.textAlignment = .center
        instructionLabel.numberOfLines = 0

        statusLabel.text = "Fetching code..."
        statusLabel.textColor = .lightGray
        statusLabel.font = UIFont.systemFont(ofSize: 14)
        statusLabel.textAlignment = .center
        // Multi-line so network/OAuth details are not clipped to one line.
        statusLabel.numberOfLines = 0
    }

    func configureButtons() {
        configureOpenButton()
        configureRetryButton()
        configureAnonymousButton()
    }

    func configureRetryButton() {
        retryButton.setTitle("Try Again", for: .normal)
        retryButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        retryButton.setTitleColor(.white, for: .normal)
        retryButton.applyFill(UIColor(white: 0.22, alpha: 1))
        retryButton.layer.cornerRadius = 12
        if #available(iOS 13.0, *) {
            retryButton.layer.cornerCurve = .continuous
        }
        retryButton.contentEdgeInsets = UIEdgeInsets(
            top: 12, left: 28, bottom: 12, right: 28
        )
        retryButton.addTarget(
            self,
            action: #selector(retrySignIn),
            for: .touchUpInside
        )
        retryButton.isHidden = true
    }

    func configureOpenButton() {
        openButton.setTitle(
            "Open google.com/device",
            for: .normal
        )
        openButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 17)
        openButton.setTitleColor(.white, for: .normal)
        openButton.applyFill(ThemeManager.shared.accent)
        openButton.layer.cornerRadius = 12
        if #available(iOS 13.0, *) {
            openButton.layer.cornerCurve = .continuous
        }
        openButton.contentEdgeInsets = UIEdgeInsets(
            top: 14, left: 28, bottom: 14, right: 28
        )
        openButton.addTarget(
            self,
            action: #selector(openVerificationURL),
            for: .touchUpInside
        )
        openButton.isHidden = true
    }

    func configureAnonymousButton() {
        anonymousButton.setTitle(
            "Continue Anonymously",
            for: .normal
        )
        anonymousButton.titleLabel?.font = UIFont.systemFont(ofSize: 15)
        anonymousButton.setTitleColor(
            UIColor(white: 0.55, alpha: 1),
            for: .normal
        )
        anonymousButton.addTarget(
            self,
            action: #selector(continueAnonymously),
            for: .touchUpInside
        )
    }

    func configureSpinner() {
        spinner.hidesWhenStopped = true
        spinner.startAnimating()
    }

    func addControlSubviews() {
        let views: [UIView] = [
            titleLabel, instructionLabel, codeChip,
            openButton, retryButton, statusLabel, spinner, anonymousButton
        ]
        views.forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
    }
}

// MARK: - Layout
private extension AuthViewController {
    func layoutTitleAndCode() {
        let padding: CGFloat = 40
        layoutTitleConstraints(padding: padding)
        layoutInstructionConstraints(padding: padding)
    }

    func layoutTitleConstraints(padding: CGFloat) {
        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(
                equalTo: view.centerXAnchor
            ),
            titleLabel.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor,
                constant: 80
            ),
            titleLabel.leadingAnchor.constraint(
                equalTo: view.leadingAnchor,
                constant: padding
            ),
            titleLabel.trailingAnchor.constraint(
                equalTo: view.trailingAnchor,
                constant: -padding
            ),
            codeChip.centerXAnchor.constraint(
                equalTo: view.centerXAnchor
            ),
            codeChip.topAnchor.constraint(
                equalTo: titleLabel.bottomAnchor,
                constant: 40
            )
        ])
    }

    func layoutInstructionConstraints(padding: CGFloat) {
        NSLayoutConstraint.activate([
            instructionLabel.centerXAnchor.constraint(
                equalTo: view.centerXAnchor
            ),
            instructionLabel.topAnchor.constraint(
                equalTo: codeChip.bottomAnchor,
                constant: 20
            ),
            instructionLabel.leadingAnchor.constraint(
                equalTo: view.leadingAnchor,
                constant: padding
            ),
            instructionLabel.trailingAnchor.constraint(
                equalTo: view.trailingAnchor,
                constant: -padding
            )
        ])
    }

    func layoutButtonsAndStatus() {
        let padding: CGFloat = 40
        layoutOpenAndStatusConstraints(padding: padding)
        layoutBottomConstraints()
    }

    func layoutOpenAndStatusConstraints(padding: CGFloat) {
        NSLayoutConstraint.activate([
            openButton.centerXAnchor.constraint(
                equalTo: view.centerXAnchor
            ),
            openButton.topAnchor.constraint(
                equalTo: instructionLabel.bottomAnchor,
                constant: 32
            ),
            retryButton.centerXAnchor.constraint(
                equalTo: view.centerXAnchor
            ),
            retryButton.topAnchor.constraint(
                equalTo: instructionLabel.bottomAnchor,
                constant: 32
            ),
            statusLabel.centerXAnchor.constraint(
                equalTo: view.centerXAnchor
            ),
            statusLabel.topAnchor.constraint(
                equalTo: openButton.bottomAnchor,
                constant: 32
            ),
            statusLabel.leadingAnchor.constraint(
                equalTo: view.leadingAnchor,
                constant: padding
            ),
            statusLabel.trailingAnchor.constraint(
                equalTo: view.trailingAnchor,
                constant: -padding
            )
        ])
    }

    func layoutBottomConstraints() {
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(
                equalTo: view.centerXAnchor
            ),
            spinner.topAnchor.constraint(
                equalTo: statusLabel.bottomAnchor,
                constant: 16
            ),
            anonymousButton.centerXAnchor.constraint(
                equalTo: view.centerXAnchor
            ),
            anonymousButton.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor,
                constant: -28
            )
        ])
    }
}

// MARK: - Auth Flow
private extension AuthViewController {
    func startAuth() {
        statusLabel.text = "Connecting to YouTube…"
        statusLabel.textColor = .lightGray
        retryButton.isHidden = true
        OAuthClient.shared.requestDeviceCode { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .failure(let error):
                    self?.showSignInFailure(error)
                case .success(let code):
                    self?.handleDeviceCode(code)
                }
            }
        }
    }

    func showSignInFailure(_ error: Error) {
        let detail = error.localizedDescription
        AppLog.auth("startAuth failed: \(detail)")
        spinner.stopAnimating()
        openButton.isHidden = true
        retryButton.isHidden = false
        statusLabel.textColor = UIColor(red: 1, green: 0.45, blue: 0.45, alpha: 1)
        let clean = NetworkSessionFactory.describe(error)
        statusLabel.text =
            "Could not start sign-in.\n\n"
            + "\(clean)\n\n"
            + "也可点 Continue Anonymously 先浏览。"
    }

    func handleDeviceCode(_ code: OAuthClient.DeviceCodeResponse) {
        codeChip.code = code.userCode
        verificationURL = URL(string: code.verificationURL)
        openButton.isHidden = false
        // Subtle enter animation for the primary CTA.
        openButton.alpha = 0
        openButton.transform = CGAffineTransform(
            scaleX: MotionStyle.enterScale,
            y: MotionStyle.enterScale
        )
        MotionStyle.animateChrome {
            self.openButton.alpha = 1
            self.openButton.transform = .identity
        }
        statusLabel.text = "Waiting for authorization..."
        statusLabel.textColor = .lightGray

        let config = OAuthClient.PollConfig(
            deviceCode: code.deviceCode,
            clientId: code.clientId,
            clientSecret: code.clientSecret,
            interval: code.interval
        )
        OAuthClient.shared.pollForToken(
            config: config
        ) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    OAuthClient.shared.isAnonymous = false
                    UserProfileStore.shared.load()
                    self?.onAuthorized?()
                case .failure(let error):
                    self?.statusLabel.text =
                        "Failed: \(error.localizedDescription)"
                    self?.spinner.stopAnimating()
                }
            }
        }
    }
}
