import XCTest
@testable import YTLite

/// Gating tests for Home/Subscriptions/Library chrome polish.
final class UIChromePolicyTests: XCTestCase {
    // MARK: - Home / Subscriptions titles (real L10n path)

    func testHomeTitleEnglishAndChineseViaL10n() {
        let en = L10n.resolve(key: L10n.Tab.home, languageCode: "en")
        XCTAssertEqual(en, "Home")
        let zh = L10n.resolve(key: L10n.Tab.home, languageCode: "zh-Hans")
        XCTAssertEqual(zh, "首页")
    }

    func testSubscriptionsTitleEnglishAndChineseViaL10n() {
        let en = L10n.resolve(key: L10n.Tab.subscriptions, languageCode: "en")
        XCTAssertEqual(en, "Subscriptions")
        let zh = L10n.resolve(
            key: L10n.Tab.subscriptions,
            languageCode: "zh-Hans"
        )
        XCTAssertEqual(zh, "订阅")
    }

    // MARK: - Nav chevron theme (Mac playlist push back button)

    func testNavChevronGlyphTintTracksTheme() {
        let theme = ThemeManager.shared
        let tint = NavChevron.glyphTint(theme: theme)
        XCTAssertEqual(tint, theme.primaryText)
        if !theme.isDark {
            XCTAssertNotEqual(
                tint,
                UIColor.white,
                "Light theme must not use white glyph"
            )
        }
    }

    func testNavChevronButtonAppliesThemeTintWithoutExtraFill() {
        let btn = NavChevronButton(
            kind: .back,
            target: nil,
            action: #selector(NSObject.description)
        )
        btn.applyTheme()
        // No second circular fill — system glass is the only chrome layer.
        XCTAssertEqual(btn.backgroundColor, UIColor.clear)
        let inner = btn.subviews.compactMap { $0 as? UIButton }.first
        XCTAssertNotNil(inner)
        XCTAssertEqual(
            inner?.tintColor,
            NavChevron.glyphTint(theme: ThemeManager.shared)
        )
        XCTAssertEqual(inner?.backgroundColor, UIColor.clear)
    }

    /// Search + watch floating backs share one style with playlist chevron glyph.
    func testMacFloatingBackStyleMatchesPlaylistGlyphAndFill() {
        let theme = ThemeManager.shared
        let button = UIButton(type: .custom)
        NavChevron.applyMacFloatingStyle(
            to: button,
            kind: .back,
            theme: theme,
            side: NavChevron.macFloatingSide
        )
        XCTAssertEqual(button.tintColor, NavChevron.glyphTint(theme: theme))
        XCTAssertEqual(
            button.backgroundColor,
            NavChevron.macFloatingFill(theme: theme)
        )
        XCTAssertEqual(
            button.layer.cornerRadius,
            NavChevron.macFloatingSide / 2,
            accuracy: 0.01
        )
        XCTAssertNotNil(button.image(for: .normal))
        if #available(iOS 13.0, *) {
            XCTAssertEqual(button.layer.cornerCurve, .circular)
        }
    }

    // MARK: - Circular avatars

    func testCircleAvatarRadiusIsHalfSide() {
        XCTAssertEqual(CircleAvatarStyle.cornerRadius(side: 32), 16)
        XCTAssertEqual(CircleAvatarStyle.cornerRadius(side: 36), 18)
        XCTAssertEqual(CircleAvatarStyle.cornerRadius(side: 48), 24)
    }

    func testCircleAvatarPrefersCircularCurve() {
        XCTAssertTrue(CircleAvatarStyle.prefersCircularCornerCurve)
    }

    func testCircleAvatarApplySetsRadiusAndCircularCurve() {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 36, height: 36))
        CircleAvatarStyle.apply(to: view, side: 36)
        XCTAssertEqual(view.layer.cornerRadius, 18, accuracy: 0.01)
        XCTAssertTrue(view.clipsToBounds)
        if #available(iOS 13.0, *) {
            XCTAssertEqual(view.layer.cornerCurve, .circular)
        }
    }

    /// Profile avatar must stay square/circle even if bar assigns an oval frame.
    func testProfileAvatarBarHostResistsOvalFrame() {
        let avatar = ProfileAvatarButton(size: 30)
        let host = ProfileAvatarBarHost(avatar: avatar)
        // Simulate Liquid Glass bar stretching customView.
        host.frame = CGRect(x: 0, y: 0, width: 22, height: 36)
        host.layoutIfNeeded()
        XCTAssertEqual(host.bounds.width, 30, accuracy: 0.01)
        XCTAssertEqual(host.bounds.height, 30, accuracy: 0.01)
        XCTAssertEqual(host.bounds.width, host.bounds.height, accuracy: 0.01)
        avatar.forceCircularLayout()
        XCTAssertEqual(avatar.bounds.width, avatar.bounds.height, accuracy: 0.01)
        XCTAssertEqual(avatar.layer.cornerRadius, avatar.designSize / 2, accuracy: 0.01)
        if #available(iOS 13.0, *) {
            XCTAssertEqual(avatar.layer.cornerCurve, .circular)
        }
    }

    func testProfileAvatarCircularCropProducesSquareImage() {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 40))
        let wide = renderer.image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 100, height: 40))
        }
        let cropped = ProfileAvatarButton.circularCropped(wide, side: 30)
        XCTAssertEqual(cropped.size.width, cropped.size.height, accuracy: 0.5)
        XCTAssertEqual(cropped.size.width, 30, accuracy: 0.5)
    }

    // MARK: - Library segment chrome

    func testLibrarySegmentImagesNotLongEnglishTitles() {
        let names = LibrarySegmentChrome.Segment.allCases.map {
            LibrarySegmentChrome.systemImageName(for: $0)
        }
        XCTAssertEqual(names.count, 3)
        XCTAssertFalse(names.contains("History"))
        XCTAssertFalse(names.contains("Downloads"))
        XCTAssertFalse(names.contains("Playlists"))
        // SF Symbol style identifiers
        XCTAssertTrue(names.allSatisfy { !$0.isEmpty && !$0.contains(" ") })
    }

    func testLibrarySegmentAccessibilityLocalized() {
        let enHist = L10n.resolve(
            key: L10n.Library.history,
            languageCode: "en"
        )
        XCTAssertEqual(enHist, "History")
        let zhHist = L10n.resolve(
            key: L10n.Library.history,
            languageCode: "zh-Hans"
        )
        XCTAssertEqual(zhHist, "历史")
        XCTAssertEqual(
            LibrarySegmentChrome.accessibilityLabel(for: .history),
            L10n.tr(L10n.Library.history)
        )
    }

    func testLibrarySegmentsPlatformSplitMacVsIOS() {
        // Current host platform images match Mac/iOS policy.
        let images = LibrarySegmentChrome.segmentImages()
        XCTAssertEqual(images.count, 3)
        XCTAssertTrue(
            LibrarySegmentChrome.usesPlatformCorrectSegments(
                isMac: PlatformStyle.isMac,
                images: images
            )
        )
        // Explicit split: Mac shows titles → composites wide; iOS icons narrow.
        if PlatformStyle.isMac {
            XCTAssertTrue(LibrarySegmentChrome.showsSegmentTitles)
            XCTAssertGreaterThanOrEqual(LibrarySegmentChrome.macMinSegmentWidth, 280)
            for image in images {
                XCTAssertGreaterThan(
                    image.size.width,
                    28,
                    "Mac must be icon+title composite"
                )
            }
        } else {
            XCTAssertFalse(LibrarySegmentChrome.showsSegmentTitles)
            for image in images {
                XCTAssertLessThan(
                    image.size.width,
                    40,
                    "iOS must be icon-only"
                )
            }
        }
    }

    func testMacLibrarySegmentWidthBandForIconTitle() {
        // On Mac Catalyst test host, width band fits icon+title.
        if PlatformStyle.isMac {
            XCTAssertGreaterThanOrEqual(LibrarySegmentChrome.macMinSegmentWidth, 280)
            XCTAssertGreaterThanOrEqual(LibrarySegmentChrome.macMaxSegmentWidth, 400)
        }
        XCTAssertEqual(
            LibrarySegmentChrome.macCenteredSegmentWidth(measured: 80),
            LibrarySegmentChrome.macMinSegmentWidth
        )
        XCTAssertEqual(
            LibrarySegmentChrome.macCenteredSegmentWidth(measured: 900),
            LibrarySegmentChrome.macMaxSegmentWidth
        )
    }

    /// Optical left nudge under title-bar tabs (user-locked: -32pt).
    func testMacLibrarySegmentCenterXOffsetIsMinus32() {
        XCTAssertEqual(LibrarySegmentChrome.macCenterXOffset, -32)
    }

    func testRootScreenTitleHidesNavButKeepsTabTitleString() {
        let vc = UIViewController()
        vc.navigationItem.title = "Home"
        RootScreenTitle.clear(on: vc, tabTitle: "首页")
        // Nav bar blank; title property kept so tab captions survive first select.
        XCTAssertEqual(vc.navigationItem.title, "")
        XCTAssertEqual(vc.title, "首页")
    }

    /// Regression: assigning UIViewController.title after tabBarItem wipes captions.
    func testTabBarItemTitleSurvivesEmptyVCTitleIfSetFirst() {
        let nav = UINavigationController()
        let title = "首页"
        let item = UITabBarItem(title: title, image: nil, tag: 0)
        nav.tabBarItem = item
        // Wrong order (old bug): blanking title after tabBarItem kills caption.
        nav.title = ""
        XCTAssertEqual(
            nav.tabBarItem.title,
            "",
            "Documents: UIViewController.title syncs into tabBarItem.title"
        )
        // Correct repair path: re-assert tabBarItem.title after any title clear.
        nav.tabBarItem.title = title
        XCTAssertEqual(nav.tabBarItem.title, title)
    }

    func testRootScreenTitleClearWithoutTabTitleDoesNotForceEmptyIfAlreadySet() {
        let vc = UIViewController()
        vc.title = "订阅"
        RootScreenTitle.clear(on: vc)
        // No tabTitle arg — leave existing title alone, only clear nav item.
        XCTAssertEqual(vc.navigationItem.title, "")
        XCTAssertEqual(vc.title, "订阅")
    }

    func testLibrarySegmentImagesMatchShowsSegmentTitlesFlag() {
        let images = LibrarySegmentChrome.segmentImages()
        if LibrarySegmentChrome.showsSegmentTitles {
            for image in images {
                XCTAssertGreaterThan(image.size.width, 28)
            }
        } else {
            for image in images {
                XCTAssertLessThan(image.size.width, 40)
            }
        }
    }

    func testMacLibraryHostsSegmentOutsideNavBar() {
        // Policy constant: when PlatformStyle.isMac, host outside.
        // On this test host, assert the pure flag matches isMac.
        XCTAssertEqual(
            LibrarySegmentChrome.hostsSegmentOutsideNavBarOnMac,
            PlatformStyle.isMac
        )
    }

    func testMacLibrarySegmentWidthClampedForCenteredPill() {
        XCTAssertEqual(
            LibrarySegmentChrome.macCenteredSegmentWidth(measured: 100),
            LibrarySegmentChrome.macMinSegmentWidth
        )
        // Within [min, max] passes through.
        let mid = (LibrarySegmentChrome.macMinSegmentWidth
            + LibrarySegmentChrome.macMaxSegmentWidth) / 2
        XCTAssertEqual(
            LibrarySegmentChrome.macCenteredSegmentWidth(measured: mid),
            mid
        )
        XCTAssertEqual(
            LibrarySegmentChrome.macCenteredSegmentWidth(measured: 900),
            LibrarySegmentChrome.macMaxSegmentWidth
        )
    }

    func testMacRootNavHiddenDoesNotApplyToModal() {
        // Library switch must not depend on a visible root nav bar on Mac.
        XCTAssertTrue(
            ResponsiveMetrics.macNavigationBarHidden(
                isRoot: true,
                isSearchScreen: false,
                isPresentedModally: false
            )
        )
        // Segment lives outside that hidden bar (see hostsSegmentOutsideNavBarOnMac).
        if PlatformStyle.isMac {
            XCTAssertTrue(LibrarySegmentChrome.hostsSegmentOutsideNavBarOnMac)
        }
    }
}
