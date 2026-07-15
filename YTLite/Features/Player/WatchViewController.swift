import AVKit
import UIKit

private func makePortraitRelatedLayout() -> UICollectionViewFlowLayout {
    let layout = UICollectionViewFlowLayout()
    layout.minimumLineSpacing = 12
    layout.minimumInteritemSpacing = 8
    layout.sectionInset = UIEdgeInsets(
        top: 0,
        left: 12,
        bottom: 16,
        right: 12
    )
    return layout
}

private func makeLandscapeRelatedLayout() -> UICollectionViewFlowLayout {
    let layout = UICollectionViewFlowLayout()
    layout.minimumLineSpacing = 12
    layout.minimumInteritemSpacing = 0
    layout.sectionInset = UIEdgeInsets(
        top: 0,
        left: 8,
        bottom: 12,
        right: 8
    )
    return layout
}

final class WatchViewController: UIViewController {
    // MARK: - Dependencies

    var initialVideo: Video
    let client: WatchService
    let engagementClient: EngagementService
    let channelInfoStore: ChannelInfoStore
    let channelViewControllerFactory: (
        String,
        String
    )
        -> UIViewController
    let videoRouter: VideoRouter
    let cache = AppCache.shared

    // MARK: - State

    var videoHistory: [Video] = []
    var watchPage: WatchPage?
    var isSubscribed: Bool = false
    var allRelatedVideos: [Video] = []
    var visibleRelatedVideos: [Video] = []
    let relatedBatchSize = 5
    var comments: [Comment] = []
    var commentsContinuation: String?
    var visibleCommentsCount = 10
    let commentsPageSize = 10
    var videoPlayerView: VideoPlayerView?
    /// Retains the active resource loader (AVURLAsset holds its delegate weakly),
    /// e.g. a source's HLS proxy.
    var activeResourceLoader: AVAssetResourceLoaderDelegate?
    var statusObservation: NSKeyValueObservation?
    var descriptionExpanded = false
    var isLoadingComments = false
    let sponsorBlock = SponsorBlockController()
    var autoplayOverlay: AutoplayOverlayView?
    let playbackFacade = PlaybackFacade()
    var pageLoadToken = CancellationToken()
    var isOuterScrollViewDragging = false
    var didSeekToSavedPosition = false
    var captionTracks: [SubtitleTrack] = []
    var activeSubtitleLanguage: String?
    var backgroundEnteredAt: Date?
    var savedPlayerForBackground: AVPlayer?
    var isRecoveringPlayback = false
    var hasSeenPlaybackError = false
    var recoveryTargetSeconds: Double?
    let queue = PlaybackQueue.shared

    // MARK: - UI Elements

    let scrollView = UIScrollView()
    let contentView = UIView()
    let relatedCollectionView: UICollectionView
    let sidebarContainer = UIView()
    let portraitRelatedLayout: UICollectionViewFlowLayout
    let landscapeRelatedLayout: UICollectionViewFlowLayout
    let playerContainer = UIView()
    let playerSpinner = UIActivityIndicatorView(
        style: .whiteLarge
    )
    let playerStatusLabel = UILabel()
    let titleLabel = UILabel()
    let metaLabel = UILabel()
    let channelAvatarView = ThumbnailImageView(
        frame: .zero
    )
    let channelNameLabel = UILabel()
    let channelMetaLabel = UILabel()
    let subscribeButton = UIButton(type: .system)
    let descriptionLabel = UILabel()
    let descriptionButton = UIButton(type: .system)
    let commentsLabel = UILabel()
    let commentsStackView = UIStackView()
    let loadMoreCommentsButton = UIButton(
        type: .system
    )
    let actionBar = UIStackView()
    let likeButton = UIButton(type: .system)
    let dislikeButton = UIButton(type: .system)
    let shareButton = UIButton(type: .system)
    let saveButton = UIButton(type: .system)
    let downloadButton = UIButton(type: .system)
    /// Mac: floating back/minimize — nav-bar chevron was clipped under titlebar
    /// (empty shell next to traffic lights). Always owned by this VC.
    let macCloseControl = UIButton(type: .custom)
    var macCloseControlInstalled = false
    var macCloseLeadingConstraint: NSLayoutConstraint?
    var macCloseTopConstraint: NSLayoutConstraint?
    var macCloseWidthConstraint: NSLayoutConstraint?
    var macCloseHeightConstraint: NSLayoutConstraint?
    let likeCountLabel = UILabel()
    let dislikeCountLabel = UILabel()
    var likeCount: String?
    var dislikeCount: String?
    var currentLikeStatus: LikeStatus = .indifferent

    // MARK: - Constraints

    var playerAspectConstraint: NSLayoutConstraint?
    /// Caps player height so comments/profile keep space on large Mac windows.
    var playerMaxHeightConstraint: NSLayoutConstraint?
    var playerPrefHeightConstraint: NSLayoutConstraint?
    /// One-shot Mac pointer hover install for action / subscribe chrome.
    var didInstallWatchPointerHover = false
    /// Last width used by `applyResponsiveChromeTypography` (skip layout thrash).
    var lastResponsiveChromeWidth: CGFloat = -1
    /// Last action-bar icon size that was rasterized onto the buttons.
    var lastActionBarIconSize: CGFloat = -1
    /// Re-entrancy guard: `updateLayoutForSize` must not re-enter via layoutIfNeeded.
    var isUpdatingWatchLayout = false
    var relatedHeightConstraint: NSLayoutConstraint?
    var playerTopConstraint: NSLayoutConstraint?
    var playerLeadingConstraint: NSLayoutConstraint?
    var playerTrailingConstraint: NSLayoutConstraint?
    var playerToSidebarConstraint: NSLayoutConstraint?
    var scrollTopToPlayerConstraint: NSLayoutConstraint?
    var scrollTrailingConstraint: NSLayoutConstraint?
    var scrollToSidebarConstraint: NSLayoutConstraint?
    var sidebarTopConstraint: NSLayoutConstraint?
    var sidebarTrailingConstraint: NSLayoutConstraint?
    var sidebarBottomConstraint: NSLayoutConstraint?
    var sidebarWidthConstraint: NSLayoutConstraint?
    var bottomCommentsConstraint: NSLayoutConstraint?
    var relatedPortraitConstraints: [NSLayoutConstraint] = []
    var relatedLandscapeConstraints: [NSLayoutConstraint] = []
    var isShowingLandscapeRelated = false
    var fullscreenSnapshot: (
        superview: UIView,
        frame: CGRect
    )?
    var isLandscapeFullscreen = false
    /// Mac: UIKit scene/window observers installed once.
    var didInstallMacWindowObservers = false
    /// Last valid window size while app-fullscreen (detect green-button shrink).
    var lastMacFullscreenHostSize: CGSize = .zero
    /// Mac: we asked for display-level full-screen (green-light equivalent).
    var didRequestMacSystemFullScreen = false
    /// Mac: suppress recover→forceExit while system FS enter is animating
    /// (mid-transition 0×0 bounds used to abort the first click).
    var macFSSettleUntil: Date?
    var channelTopToMeta: NSLayoutConstraint?
    var channelTopToDesc: NSLayoutConstraint?

    // MARK: - Computed Properties

    override var shouldAutorotate: Bool {
        true
    }

    override var supportedInterfaceOrientations:
        UIInterfaceOrientationMask {
        .allButUpsideDown
    }

    var isPlaylistMode: Bool {
        queue.playlistTitle != nil
    }

    // MARK: - Initializers

    init(
        video: Video,
        watchService: WatchService,
        engagementService: EngagementService,
        channelInfoStore: ChannelInfoStore,
        channelViewControllerFactory: @escaping (
            String,
            String
        )
            -> UIViewController,
        videoRouter: VideoRouter = .shared
    ) {
        let portraitLayout = makePortraitRelatedLayout()
        portraitRelatedLayout = portraitLayout

        let landscapeLayout = makeLandscapeRelatedLayout()
        landscapeRelatedLayout = landscapeLayout

        relatedCollectionView = UICollectionView(
            frame: .zero,
            collectionViewLayout: portraitLayout
        )
        initialVideo = video
        client = watchService
        engagementClient = engagementService
        self.channelInfoStore = channelInfoStore
        self.channelViewControllerFactory = channelViewControllerFactory
        self.videoRouter = videoRouter
        super.init(nibName: nil, bundle: nil)
        playbackFacade.context = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("Not implemented")
    }

    // MARK: - View Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupLayout()
        applyTheme()
        setupNavigationBar()
        loadInitialState()
        let id = initialVideo.id
        if let cached = cache.cachedWatchPage(
            videoId: id
        ) {
            applyWatchPage(cached)
        }
        loadWatchPage()
        addNotificationObservers()
        installMacWindowObserversIfNeeded()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        if UIDevice.current.userInterfaceIdiom != .pad {
            UIDevice.current.endGeneratingDeviceOrientationNotifications()
        }
        statusObservation?.invalidate()
        statusObservation = nil
        if let item = videoPlayerView?.player?.currentItem {
            stopObservingPlayerItem(item)
        }
        videoPlayerView?.detach()
        playbackFacade.reset()
    }
}
