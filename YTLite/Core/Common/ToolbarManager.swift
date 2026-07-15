import UIKit

private func resized(_ name: String, size: CGFloat) -> UIImage? {
    guard let img = UIImage(named: name) else {
        return nil
    }
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
    return renderer.image { _ in
        img.draw(in: CGRect(origin: .zero, size: CGSize(width: size, height: size)))
    }
    .withRenderingMode(.alwaysTemplate)
}

/// Builds and manages the shared navigation bar buttons (Search + Settings + Profile/Avatar).
/// Call `install(in:)` from any UIViewController that needs them.
final class ToolbarManager {
    static let shared = ToolbarManager()

    var searchViewControllerFactory: (() -> SearchViewController)?

    private init() {}

    // MARK: - Install buttons in a view controller

    func install(in vc: UIViewController) {
        // macOS: actions live in the window title bar trailing chrome
        // (MacActionChromeBar). Never install nav right items — they render
        // as a second glass pill lower than the real title-bar slot.
        if PlatformStyle.prefersMacTitlebarActions {
            vc.navigationItem.rightBarButtonItems = nil
            vc.navigationItem.rightBarButtonItem = nil
            return
        }

        let tint: UIColor
        if #available(iOS 13.0, *) {
            tint = ThemeManager.shared.isDark ? .white : .label
        } else {
            tint = ThemeManager.shared.isDark ? .white : .darkGray
        }
        let searchBtn = UIBarButtonItem(
            image: resized("icon_Magnifyingglass", size: 22),
            style: .plain,
            target: vc,
            action: #selector(UIViewController.toolbarOpenSearch)
        )
        searchBtn.tintColor = tint

        let settingsBtn = UIBarButtonItem(
            image: resized("icon_Gear", size: 22),
            style: .plain,
            target: vc,
            action: #selector(UIViewController.toolbarOpenSettings)
        )
        settingsBtn.tintColor = tint

        let profileBtn = makeProfileButton(
            target: vc,
            action: #selector(UIViewController.toolbarOpenProfile)
        )

        vc.navigationItem.rightBarButtonItems = [profileBtn, settingsBtn, searchBtn]
        NotificationCenter.default.addObserver(
            vc,
            selector: #selector(UIViewController.toolbarRefreshProfileButton),
            name: UserProfileStore.didUpdateNotification,
            object: nil
        )
    }

    private func makeProfileButton(target: AnyObject, action: Selector) -> UIBarButtonItem {
        let button = ProfileAvatarButton()
        button.refresh()
        button.addTarget(target, action: action, for: .touchUpInside)
        // Rigid square host — UIBarButtonItem glass chrome stretches bare
        // customViews into ovals; a fixed host keeps a true circle.
        let host = ProfileAvatarBarHost(avatar: button)
        return UIBarButtonItem(customView: host)
    }
}

// MARK: - UIViewController extension for toolbar actions

extension UIViewController {
    @objc
    func toolbarOpenSearch() {
        let searchVC = ToolbarManager.shared.searchViewControllerFactory?()
        guard let searchVC else {
            assertionFailure("ToolbarManager search factory is not configured")
            return
        }
        navigationController?.pushViewController(searchVC, animated: true)
    }

    @objc
    func toolbarOpenSettings() {
        let nav = RotatingNavigationController(rootViewController: SettingsViewController())
        nav.modalPresentationStyle = .pageSheet
        if #available(iOS 15, *) {
            if let sheet = nav.sheetPresentationController {
                sheet.detents = [.medium(), .large()]
                sheet.prefersGrabberVisible = true
            }
        }
        present(nav, animated: true)
    }

    @objc
    func toolbarOpenProfile() {
        if OAuthClient.shared.isSignedIn {
            showSignedInSheet()
        } else {
            showSignedOutSheet()
        }
    }

    private func showSignedInSheet() {
        let name = UserProfileStore.shared.displayName ?? "Account"
        let sheet = UIAlertController(
            title: name,
            message: nil,
            preferredStyle: .actionSheet
        )
        sheet.addAction(UIAlertAction(
            title: "Sign Out",
            style: .destructive
        ) { _ in
            OAuthClient.shared.signOut()
            UserProfileStore.shared.clear()
            AppCache.shared.clearHomeFeed()
            NotificationCenter.default.post(
                name: .userDidSignOut,
                object: nil
            )
            (UIApplication.shared.delegate as? AppDelegate)?.showAuth()
        })
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        configurePopover(sheet)
        present(sheet, animated: true)
    }

    private func showSignedOutSheet() {
        let sheet = UIAlertController(
            title: "Not signed in",
            message: nil,
            preferredStyle: .actionSheet
        )
        sheet.addAction(UIAlertAction(
            title: "Sign In",
            style: .default
        ) { _ in
            (UIApplication.shared.delegate as? AppDelegate)?.showAuth()
        })
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        configurePopover(sheet)
        present(sheet, animated: true)
    }

    @objc
    func toolbarRefreshProfileButton() {
        for item in navigationItem.rightBarButtonItems ?? [] {
            if let avatar = item.customView as? ProfileAvatarButton {
                avatar.refresh()
            } else if let host = item.customView as? ProfileAvatarBarHost {
                host.avatar.refresh()
            }
        }
    }

    private func configurePopover(_ alert: UIAlertController) {
        if let pop = alert.popoverPresentationController {
            if let btn = navigationItem.rightBarButtonItems?.first(where: {
                $0.customView is ProfileAvatarButton
                    || $0.customView is ProfileAvatarBarHost
            }) {
                pop.barButtonItem = btn
            } else {
                pop.sourceView = view
                pop.sourceRect = CGRect(
                    x: view.bounds.midX,
                    y: view.bounds.midY,
                    width: 0,
                    height: 0
                )
                pop.permittedArrowDirections = []
            }
        }
    }
}

// MARK: - AppDelegate helpers

extension AppDelegate {
    @objc
    func showAuth() {
        DispatchQueue.main.async { [weak self] in
            guard let window = self?.window else {
                return
            }
            let auth = AuthViewController()
            auth.onAuthorized = { [weak self] in
                UserProfileStore.shared.load()
                self?.showMain()
            }
            auth.onContinueAnonymously = { [weak self] in
                self?.showMain()
            }
            if let presented = window.rootViewController?.presentedViewController {
                presented.dismiss(animated: false) {
                    window.rootViewController = auth
                }
            } else {
                window.rootViewController = auth
            }
        }
    }
}

// MARK: - Profile avatar (true circle in nav bar)

/// Fixed square host for `UIBarButtonItem(customView:)`.
/// iOS 26 Liquid Glass stretches bare custom views into ovals — this host
/// refuses to change aspect ratio.
final class ProfileAvatarBarHost: UIView {
    let avatar: ProfileAvatarButton
    private let side: CGFloat

    init(avatar: ProfileAvatarButton) {
        self.avatar = avatar
        self.side = avatar.designSize
        super.init(frame: CGRect(x: 0, y: 0, width: side, height: side))
        clipsToBounds = false
        isUserInteractionEnabled = true
        backgroundColor = .clear
        // Frame-based: bar button customView uses the view's bounds as hit size.
        translatesAutoresizingMaskIntoConstraints = true
        autoresizingMask = []
        avatar.translatesAutoresizingMaskIntoConstraints = true
        avatar.autoresizingMask = []
        avatar.frame = CGRect(x: 0, y: 0, width: side, height: side)
        addSubview(avatar)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: side, height: side)
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        CGSize(width: side, height: side)
    }

    override var frame: CGRect {
        get { super.frame }
        set {
            // Keep square even if the bar assigns a non-square frame.
            var f = newValue
            f.size = CGSize(width: side, height: side)
            super.frame = f
        }
    }

    override var bounds: CGRect {
        get { super.bounds }
        set {
            super.bounds = CGRect(x: 0, y: 0, width: side, height: side)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Re-pin square after bar layout passes.
        if bounds.size != CGSize(width: side, height: side) {
            bounds = CGRect(x: 0, y: 0, width: side, height: side)
        }
        avatar.frame = CGRect(x: 0, y: 0, width: side, height: side)
        avatar.forceCircularLayout()
    }
}

final class ProfileAvatarButton: UIButton {
    /// Design diameter — always a perfect circle of this size.
    let designSize: CGFloat
    private let circleMask = CAShapeLayer()

    var size: CGFloat { designSize }

    convenience init() {
        self.init(size: 30)
    }

    init(size: CGFloat) {
        self.designSize = size
        super.init(frame: CGRect(x: 0, y: 0, width: size, height: size))
        contentMode = .scaleAspectFill
        imageView?.contentMode = .scaleAspectFill
        imageView?.clipsToBounds = true
        imageView?.tintColor = nil
        clipsToBounds = true
        layer.masksToBounds = true
        // Hard circular mask (survives non-square bounds from bar chrome).
        circleMask.fillColor = UIColor.black.cgColor
        layer.mask = circleMask
        forceCircularLayout()
        refresh()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleThemeChange),
            name: ThemeManager.didChangeNotification,
            object: nil
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: designSize, height: designSize)
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        CGSize(width: designSize, height: designSize)
    }

    override var frame: CGRect {
        get { super.frame }
        set {
            var f = newValue
            f.size = CGSize(width: designSize, height: designSize)
            super.frame = f
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        forceCircularLayout()
    }

    /// Call after any bar layout — enforces perfect circle of `designSize`.
    func forceCircularLayout() {
        let side = designSize
        if bounds.size != CGSize(width: side, height: side) {
            bounds = CGRect(origin: .zero, size: CGSize(width: side, height: side))
        }
        let oval = CGRect(x: 0, y: 0, width: side, height: side)
        circleMask.frame = oval
        circleMask.path = UIBezierPath(ovalIn: oval).cgPath
        layer.cornerRadius = side / 2
        layer.masksToBounds = true
        if #available(iOS 13.0, *) {
            layer.cornerCurve = .circular
        }
        if let imageView {
            imageView.frame = oval
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            imageView.layer.cornerRadius = side / 2
            imageView.layer.masksToBounds = true
            if #available(iOS 13.0, *) {
                imageView.layer.cornerCurve = .circular
            }
        }
    }

    @objc
    private func handleThemeChange() {
        refresh()
    }

    private var iconTint: UIColor {
        if #available(iOS 13.0, *) {
            return ThemeManager.shared.isDark ? .white : .label
        }
        return ThemeManager.shared.isDark ? .white : .darkGray
    }

    func refresh() {
        let tint = iconTint
        tintColor = tint
        imageView?.tintColor = tint
        if let avatar = UserProfileStore.shared.avatarImage {
            // Crop real photos to a square first so aspectFill can't oval-stretch.
            setImage(
                Self.circularCropped(avatar, side: designSize)
                    .withRenderingMode(.alwaysOriginal),
                for: .normal
            )
        } else {
            setImage(defaultImage(tint: tint), for: .normal)
        }
        forceCircularLayout()
    }

    /// Center-crop to square then scale — prevents elliptical display of photos.
    static func circularCropped(_ image: UIImage, side: CGFloat) -> UIImage {
        let pixelSide = max(side, 1) * UIScreen.main.scale
        let imgSize = image.size
        guard imgSize.width > 0, imgSize.height > 0 else {
            return image
        }
        let minSide = min(imgSize.width, imgSize.height)
        let origin = CGPoint(
            x: (imgSize.width - minSide) / 2,
            y: (imgSize.height - minSide) / 2
        )
        let cropRect = CGRect(origin: origin, size: CGSize(width: minSide, height: minSide))
        guard let cg = image.cgImage?.cropping(to: CGRect(
            x: cropRect.origin.x * image.scale,
            y: cropRect.origin.y * image.scale,
            width: cropRect.size.width * image.scale,
            height: cropRect.size.height * image.scale
        )) else {
            return image
        }
        let square = UIImage(cgImage: cg, scale: image.scale, orientation: image.imageOrientation)
        let outSize = CGSize(width: side, height: side)
        let renderer = UIGraphicsImageRenderer(size: outSize)
        return renderer.image { _ in
            let path = UIBezierPath(ovalIn: CGRect(origin: .zero, size: outSize))
            path.addClip()
            square.draw(in: CGRect(origin: .zero, size: outSize))
        }
    }

    private func defaultImage(tint: UIColor) -> UIImage? {
        if #available(iOS 13, *) {
            let config = UIImage.SymbolConfiguration(pointSize: designSize * 0.9, weight: .regular)
            if let symbol = UIImage(
                systemName: "person.crop.circle.fill",
                withConfiguration: config
            ) {
                return symbol.withRenderingMode(.alwaysTemplate)
            }
        }
        if let asset = UIImage(named: "icon_person_fill") {
            let out = CGSize(width: designSize, height: designSize)
            let renderer = UIGraphicsImageRenderer(size: out)
            return renderer.image { _ in
                asset.draw(in: CGRect(origin: .zero, size: out))
            }.withRenderingMode(.alwaysTemplate)
        }
        return drawPersonPlaceholder(color: tint)
    }

    private func drawPersonPlaceholder(color: UIColor) -> UIImage {
        let side = designSize
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        return renderer.image { ctx in
            let cgCtx = ctx.cgContext
            color.setStroke()
            color.withAlphaComponent(0.2).setFill()
            cgCtx.setLineWidth(1.5)
            cgCtx.addEllipse(in: CGRect(x: 1, y: 1, width: side - 2, height: side - 2))
            cgCtx.drawPath(using: .fillStroke)
            color.setFill()
            let headR = side * 0.22
            let headRect = CGRect(
                x: side / 2 - headR,
                y: side * 0.2,
                width: headR * 2,
                height: headR * 2
            )
            cgCtx.fillEllipse(in: headRect)
            let bodyR = side * 0.32
            let bodyRect = CGRect(
                x: side / 2 - bodyR,
                y: side * 0.52,
                width: bodyR * 2,
                height: bodyR * 2
            )
            cgCtx.addEllipse(in: bodyRect)
            cgCtx.clip()
            cgCtx.fill(CGRect(x: 0, y: 0, width: side, height: side))
        }
        .withRenderingMode(.alwaysTemplate)
    }
}
