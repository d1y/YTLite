import UIKit

/// Library screen with a segmented control (SF Symbol icons).
/// Three embedded child nav controllers — no push/pop, instant switching.
/// On Mac the segment control is hosted **in-content** (root nav bar is hidden).
final class LibraryViewController: UIViewController {
    // MARK: - Segments

    private typealias Segment = LibrarySegmentChrome.Segment

    private let dependencies: AppDependencies

    // MARK: - Child nav controllers

    private lazy var childNavVCs: [UINavigationController] = {
        let navs = [
            RotatingNavigationController(
                rootViewController: HistoryViewController(
                    service: dependencies.historyService,
                    channelViewControllerFactory:
                        dependencies.makeChannelViewController
                )
            ),
            RotatingNavigationController(rootViewController: DownloadsViewController()),
            RotatingNavigationController(
                rootViewController: PlaylistsViewController(
                    service: dependencies.playlistService,
                    channelViewControllerFactory:
                        dependencies.makeChannelViewController
                )
            )
        ]
        navs.forEach { $0.setNavigationBarHidden(true, animated: false) }
        return navs
    }()

    // MARK: - UI

    private let segmentedControl = UISegmentedControl(items: [])
    /// Host for segment control when it is not in the nav titleView (Mac).
    private let segmentHost = UIView()
    private let contentView = UIView()
    private var currentChild: UINavigationController?
    private var contentTopToSafe: NSLayoutConstraint?
    private var contentTopToSegment: NSLayoutConstraint?
    private var macSegmentWidthConstraint: NSLayoutConstraint?

    // MARK: - Lifecycle

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Keep title string for tab sync; hide from nav bar (segment is chrome).
        RootScreenTitle.clear(on: self, tabTitle: L10n.tr(L10n.Tab.library))
        setupSegmentedControl()
        setupSegmentHostIfNeeded()
        setupContentView()
        ToolbarManager.shared.install(in: self)
        applyTheme()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applyTheme),
            name: ThemeManager.didChangeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLanguageChange),
            name: .appLanguageDidChange,
            object: nil
        )
        show(segment: .history, animated: false)
    }

    @objc
    private func handleLanguageChange() {
        let selected = segmentedControl.selectedSegmentIndex
        configureSegmentItems()
        segmentedControl.selectedSegmentIndex = max(0, selected)
        applySegmentAccessibility()
        applyTheme()
        if LibrarySegmentChrome.hostsSegmentOutsideNavBarOnMac {
            updateMacSegmentWidth()
        } else {
            segmentedControl.sizeToFit()
            segmentedControl.frame.size.width = min(
                max(segmentedControl.frame.width + 16, 260),
                360
            )
            navigationItem.titleView = segmentedControl
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if LibrarySegmentChrome.hostsSegmentOutsideNavBarOnMac {
            updateMacSegmentWidth()
        }
    }

    // MARK: - Setup

    private func setupSegmentedControl() {
        configureSegmentItems()
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.addTarget(
            self,
            action: #selector(segmentChanged),
            for: .valueChanged
        )
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        applySegmentAccessibility()
    }

    /// Mac: icon+title composites. iOS: icon-only (Apple: image XOR title).
    private func configureSegmentItems() {
        while segmentedControl.numberOfSegments > 0 {
            segmentedControl.removeSegment(at: 0, animated: false)
        }
        let images = LibrarySegmentChrome.segmentImages()
        for (index, image) in images.enumerated() {
            segmentedControl.insertSegment(with: image, at: index, animated: false)
        }
    }

    private func applySegmentAccessibility() {
        for segment in Segment.allCases {
            segmentedControl.setAccessibilityLabel(
                LibrarySegmentChrome.accessibilityLabel(for: segment),
                forSegmentAt: segment.rawValue
            )
        }
    }

    /// Mac: root nav stripped — **icon+title** segments horizontally centered
    /// under title-bar tabs. iOS: icon-only in nav titleView.
    private func setupSegmentHostIfNeeded() {
        guard LibrarySegmentChrome.hostsSegmentOutsideNavBarOnMac else {
            navigationItem.titleView = segmentedControl
            segmentedControl.translatesAutoresizingMaskIntoConstraints = true
            segmentedControl.sizeToFit()
            // iOS icon-only compact width.
            segmentedControl.frame.size.width = min(
                max(segmentedControl.frame.width + 12, 140),
                220
            )
            return
        }
        navigationItem.titleView = nil
        // Hide nav title only — keep `title` for tab caption sync.
        navigationItem.title = ""
        segmentHost.translatesAutoresizingMaskIntoConstraints = false
        segmentHost.backgroundColor = .clear
        view.addSubview(segmentHost)
        segmentHost.addSubview(segmentedControl)
        let margin = LibrarySegmentChrome.macHorizontalMargin
        let width = segmentedControl.widthAnchor.constraint(
            equalToConstant: LibrarySegmentChrome.macMinSegmentWidth
        )
        macSegmentWidthConstraint = width
        NSLayoutConstraint.activate([
            segmentHost.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor,
                constant: 8
            ),
            segmentHost.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            segmentHost.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            segmentHost.heightAnchor.constraint(equalToConstant: 36),
            // -32pt leading optical offset to match title-bar tabs above.
            segmentedControl.centerXAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.centerXAnchor,
                constant: LibrarySegmentChrome.macCenterXOffset
            ),
            segmentedControl.centerYAnchor.constraint(
                equalTo: segmentHost.centerYAnchor
            ),
            segmentedControl.heightAnchor.constraint(equalToConstant: 32),
            segmentedControl.leadingAnchor.constraint(
                greaterThanOrEqualTo: view.safeAreaLayoutGuide.leadingAnchor,
                constant: margin
            ),
            segmentedControl.trailingAnchor.constraint(
                lessThanOrEqualTo: view.safeAreaLayoutGuide.trailingAnchor,
                constant: -margin
            ),
            width
        ])
        updateMacSegmentWidth()
    }

    /// Mac icon+title width; stay horizontally centered under tabs.
    private func updateMacSegmentWidth() {
        guard LibrarySegmentChrome.hostsSegmentOutsideNavBarOnMac else {
            return
        }
        segmentedControl.setNeedsLayout()
        segmentedControl.layoutIfNeeded()
        let fitting = segmentedControl.sizeThatFits(
            CGSize(width: 600, height: 32)
        )
        let clamped = LibrarySegmentChrome.macCenteredSegmentWidth(
            measured: max(fitting.width + 16, LibrarySegmentChrome.macMinSegmentWidth)
        )
        if abs((macSegmentWidthConstraint?.constant ?? 0) - clamped) > 0.5 {
            macSegmentWidthConstraint?.constant = clamped
        }
    }

    private func setupContentView() {
        contentView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(contentView)
        let topToSafe = contentView.topAnchor.constraint(
            equalTo: view.safeAreaLayoutGuide.topAnchor
        )
        contentTopToSafe = topToSafe
        var constraints: [NSLayoutConstraint] = [
            contentView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ]
        if LibrarySegmentChrome.hostsSegmentOutsideNavBarOnMac {
            topToSafe.isActive = false
            let topToSeg = contentView.topAnchor.constraint(
                equalTo: segmentHost.bottomAnchor,
                constant: 8
            )
            contentTopToSegment = topToSeg
            constraints.append(topToSeg)
        } else {
            constraints.append(topToSafe)
        }
        NSLayoutConstraint.activate(constraints)
    }

    // MARK: - Segment switching

    @objc
    private func segmentChanged() {
        let segment = Segment(rawValue: segmentedControl.selectedSegmentIndex)
            ?? .history
        show(segment: segment, animated: false)
    }

    private func show(segment: Segment, animated: Bool) {
        let newChild = childNavVCs[segment.rawValue]
        guard newChild !== currentChild else {
            return
        }

        if let old = currentChild {
            old.willMove(toParent: nil)
            old.view.removeFromSuperview()
            old.removeFromParent()
        }

        addChild(newChild)
        newChild.view.frame = contentView.bounds
        newChild.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        contentView.addSubview(newChild.view)
        newChild.didMove(toParent: self)
        currentChild = newChild
    }

    // MARK: - Theme

    @objc
    private func applyTheme() {
        let theme = ThemeManager.shared
        view.backgroundColor = theme.background
        contentView.backgroundColor = theme.background
        segmentHost.backgroundColor = .clear
        if #available(iOS 13, *) {
            segmentedControl.selectedSegmentTintColor = theme.accent
            segmentedControl.setTitleTextAttributes(
                [.foregroundColor: theme.primaryText],
                for: .normal
            )
            segmentedControl.setTitleTextAttributes(
                [.foregroundColor: UIColor.white],
                for: .selected
            )
        }
        segmentedControl.tintColor = theme.primaryText
    }
}

// MARK: - UISegmentedControl accessibility helper (iOS 12+)

private extension UISegmentedControl {
    func setAccessibilityLabel(_ label: String, forSegmentAt index: Int) {
        // Subviews of segments are private; set on control and image.
        if #available(iOS 13.0, *) {
            // Keep a11y via accessibilityElements when possible.
        }
        if index == selectedSegmentIndex {
            accessibilityValue = label
        }
        // Store labels via accessibilityLabel composition for VoiceOver.
        let all = LibrarySegmentChrome.Segment.allCases.map {
            LibrarySegmentChrome.accessibilityLabel(for: $0)
        }
        accessibilityLabel = all.joined(separator: ", ")
        _ = label
    }
}
