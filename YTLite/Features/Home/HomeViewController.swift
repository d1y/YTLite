import UIKit

class HomeViewController: VideosViewController {
    private let service: FeedService
    private let cache: AppCache
    /// Cancels stale completions / watchdogs when a newer load starts.
    private var loadGeneration = UUID()

    override var columns: Int {
        if UIDevice.current.userInterfaceIdiom == .phone {
            return 1
        }
        let width = view.bounds.width
        if width < 500 {
            return 1
        }
        return width > view.bounds.height ? 3 : 2
    }

    private lazy var errorLabel: UILabel = {
        let label = UILabel()
        label.text = "Couldn't load feed\nPull down to retry"
        label.textColor = .lightGray
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = UIFont.systemFont(ofSize: 15)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isHidden = true
        return label
    }()

    private lazy var signInEmptyView: SignInEmptyStateView = {
        let emptyView = SignInEmptyStateView(message: "Sign in to see your recommendations")
        emptyView.isHidden = true
        emptyView.onSignIn = { [weak self] in self?.toolbarOpenProfile() }
        return emptyView
    }()

    init(
        service: FeedService,
        cache: AppCache = .shared,
        channelViewControllerFactory: @escaping (
            String,
            String
        ) -> UIViewController,
        videoRouter: VideoRouter = .shared
    ) {
        self.service = service
        self.cache = cache
        super.init(
            channelViewControllerFactory: channelViewControllerFactory,
            videoRouter: videoRouter
        )
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // No nav "首页" — keep title string for tab sync only.
        RootScreenTitle.clear(on: self, tabTitle: L10n.tr(L10n.Tab.home))
        AppLog.home("viewDidLoad")
        setupEmptyViews()
        setupToolbar()
        observeSignOut()
        observeTokenRefresh()
        loadCachedOrFetchFeed()
    }

    private func setupEmptyViews() {
        view.addSubview(errorLabel)
        view.addSubview(signInEmptyView)
        NSLayoutConstraint.activate([
            errorLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            errorLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            errorLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            errorLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),

            signInEmptyView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            signInEmptyView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),
            signInEmptyView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            signInEmptyView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40)
        ])
    }

    private func observeSignOut() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSignOut),
            name: .userDidSignOut,
            object: nil
        )
    }

    private func loadCachedOrFetchFeed() {
        cache.loadHomeFeed { [weak self] cachedPage in
            guard let self else {
                return
            }
            if let cachedPage {
                AppLog.home("cache-hit → showing \(cachedPage.videos.count) videos instantly")
                self.isLoadingInitial = false
                self.spinner.stopAnimating()
                self.setPage(cachedPage)
            } else {
                AppLog.home("no cache → loading from network")
                self.loadFeed()
            }
        }
    }

    private func setupToolbar() {
        ToolbarManager.shared.install(in: self)
    }

    @objc
    private func handleSignOut() {
        ScreenVisitTracker.reset()
        cache.clearHomeFeed()
        setPage(FeedPage(videos: [], continuation: nil))
        toolbarRefreshProfileButton()
        loadFeed()
    }

    override func handleRefresh() {
        cache.clearHomeFeed()
        loadFeed()
    }

    func loadFeed() {
        let t0 = Date()
        AppLog.home("network fetch start")
        errorLabel.isHidden = true
        signInEmptyView.isHidden = true
        isLoadingInitial = true
        spinner.startAnimating()
        collectionView?.reloadData()

        // Watchdog: never leave the skeleton forever if the network stalls.
        let generation = UUID()
        loadGeneration = generation
        DispatchQueue.main.asyncAfter(deadline: .now() + 25) { [weak self] in
            guard let self, self.loadGeneration == generation, self.isLoadingInitial else {
                return
            }
            AppLog.home("network fetch watchdog — still loading after 25s")
            self.setPage(FeedPage(videos: [], continuation: nil))
            self.errorLabel.text =
                "Loading is taking too long.\nPull down to retry.\n\n"
                + "If you use Clash/Surge, enable TUN for all apps."
            self.errorLabel.isHidden = false
        }

        service.fetchHomeFeed { [weak self] result in
            DispatchQueue.main.async {
                guard let self else {
                    return
                }
                guard self.loadGeneration == generation else {
                    return
                }
                let ms = Int(Date().timeIntervalSince(t0) * 1_000)
                switch result {
                case .success(let page):
                    AppLog.home(
                        "network fetch done \(ms)ms videos=\(page.videos.count)"
                    )
                    if page.videos.isEmpty {
                        self.setPage(page)
                        if OAuthClient.shared.isAnonymous {
                            self.signInEmptyView.isHidden = false
                        } else {
                            self.errorLabel.text =
                                "No videos returned.\nPull down to retry"
                            self.errorLabel.isHidden = false
                        }
                    } else {
                        self.cache.setHomeFeed(page)
                        self.setPage(page)
                    }
                case .failure(let err):
                    AppLog.home("network fetch failed \(ms)ms: \(err)")
                    self.setPage(FeedPage(videos: [], continuation: nil))
                    if OAuthClient.shared.isAnonymous {
                        self.signInEmptyView.isHidden = false
                    } else {
                        let detail = (err as? LocalizedError)?
                            .errorDescription ?? err.localizedDescription
                        self.errorLabel.text =
                            "Couldn't load feed\n\(detail)\nPull down to retry"
                        self.errorLabel.isHidden = false
                    }
                }
            }
        }
    }

    override func handleLoadMore() {
        guard let continuation = currentContinuation else {
            finishLoadingMore()
            return
        }

        service.fetchNextPage(continuation: continuation) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let page):
                    self?.appendPage(page)
                case .failure:
                    self?.finishLoadingMore()
                }
            }
        }
    }
}
