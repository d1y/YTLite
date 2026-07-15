import UIKit

class SearchViewController: UIViewController {
    let service: SearchService
    let channelViewControllerFactory: (
        String,
        String
    ) -> UIViewController
    let videoRouter: VideoRouter
    var results: [Video] = []
    var lastQuery: String = ""
    var activeSearchQuery: String?
    var searchCancellationToken = CancellationToken()
    var continuationToken: String?
    var isLoadingNextPage = false
    var panelMode: PanelMode = .hidden
    var suggestions: [String] = []
    var suggestWorkItem: DispatchWorkItem?
    var suggestToken = CancellationToken()
    let searchHistory = SearchHistoryStore.shared

    /// iOS: system search bar. Mac: `macSearchField` is the live control.
    let searchBar = UISearchBar()
    /// Mac desktop field — subclass forces text + IME marked-text visibility.
    let macSearchField = MacSearchTextField()
    let tableView = UITableView()
    let refreshControl = UIRefreshControl()

    /// Mac: custom row [back] [field] — system nav bar is hidden.
    private let macChrome = UIView()
    private let macBackButton = UIButton(type: .custom)
    private var macChromeHeightConstraint: NSLayoutConstraint?
    private var macBackHeightConstraint: NSLayoutConstraint?
    private var macFieldHeightConstraint: NSLayoutConstraint?

    init(
        service: SearchService,
        channelViewControllerFactory: @escaping (
            String,
            String
        ) -> UIViewController,
        videoRouter: VideoRouter = .shared
    ) {
        self.service = service
        self.channelViewControllerFactory = channelViewControllerFactory
        self.videoRouter = videoRouter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureChrome()
        if PlatformStyle.isMac {
            setupMacSearchChrome()
        } else {
            setupSearchBar()
        }
        setupTableView()
        applyTheme()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applyTheme),
            name: ThemeManager.didChangeNotification,
            object: nil
        )
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if PlatformStyle.isMac {
            navigationController?.setNavigationBarHidden(true, animated: animated)
            navigationController?.navigationBar.isHidden = true
            applyMacSearchTheme(ThemeManager.shared)
            DispatchQueue.main.async { [weak self] in
                self?.macSearchField.becomeFirstResponder()
            }
        }
    }

    // MARK: - Setup

    private func configureChrome() {
        navigationItem.largeTitleDisplayMode = .never
        if PlatformStyle.isMac {
            title = nil
            navigationItem.title = ""
            // Hide system back — custom circular back owns the chrome.
            navigationItem.hidesBackButton = true
            navigationItem.leftBarButtonItem = nil
        } else {
            title = "Search"
        }
    }

    /// Mac desktop chrome: circular back + text field at the **same** height.
    private func setupMacSearchChrome() {
        let controlHeight = ResponsiveMetrics.macSearchControlHeight()

        macChrome.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(macChrome)

        configureMacBackButton(controlHeight: controlHeight)
        configureMacSearchField(controlHeight: controlHeight)
        activateMacChromeConstraints(controlHeight: controlHeight)
    }

    private func configureMacBackButton(controlHeight: CGFloat) {
        macBackButton.translatesAutoresizingMaskIntoConstraints = false
        // Match playlist / watch Mac back: shared NavChevron floating style.
        NavChevron.applyMacFloatingStyle(
            to: macBackButton,
            kind: .back,
            theme: ThemeManager.shared,
            side: controlHeight
        )
        macBackButton.accessibilityLabel = "Back"
        macBackButton.addTarget(
            self,
            action: #selector(macBackTapped),
            for: .touchUpInside
        )
        MotionStyle.installPressFeedback(on: macBackButton)
        MacPointerHover.install(on: macBackButton)
        macChrome.addSubview(macBackButton)
    }

    private func configureMacSearchField(controlHeight: CGFloat) {
        // Single-layer field on chrome (no nested shell) — Apple docs:
        // textColor / defaultTextAttributes / typingAttributes / markedTextStyle
        // must all carry a high-contrast foreground for committed + IME text.
        macSearchField.translatesAutoresizingMaskIntoConstraints = false
        macSearchField.layer.cornerRadius = controlHeight / 2
        macSearchField.clipsToBounds = true
        if #available(iOS 13.0, *) {
            macSearchField.layer.cornerCurve = .continuous
        }
        macSearchField.leftView = makeSearchFieldIconView(height: 22)
        macSearchField.leftViewMode = .always
        if !lastQuery.isEmpty {
            macSearchField.text = lastQuery
        }
        macSearchField.delegate = self
        macSearchField.addTarget(
            self,
            action: #selector(macSearchFieldChanged),
            for: .editingChanged
        )
        MacPointerHover.install(on: macSearchField)
        macChrome.addSubview(macSearchField)
        applyMacSearchTheme(ThemeManager.shared)
    }

    private func activateMacChromeConstraints(controlHeight: CGFloat) {
        let chromeH = macChrome.heightAnchor.constraint(
            equalToConstant: controlHeight + 16
        )
        macChromeHeightConstraint = chromeH
        let backH = macBackButton.heightAnchor.constraint(
            equalToConstant: controlHeight
        )
        let backW = macBackButton.widthAnchor.constraint(
            equalToConstant: controlHeight
        )
        macBackHeightConstraint = backH
        let fieldH = macSearchField.heightAnchor.constraint(
            equalToConstant: controlHeight
        )
        macFieldHeightConstraint = fieldH
        let equalHeights = macSearchField.heightAnchor.constraint(
            equalTo: macBackButton.heightAnchor
        )

        NSLayoutConstraint.activate([
            macChrome.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor
            ),
            macChrome.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            macChrome.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            chromeH,

            macBackButton.leadingAnchor.constraint(
                equalTo: macChrome.leadingAnchor,
                constant: 16
            ),
            macBackButton.centerYAnchor.constraint(
                equalTo: macChrome.centerYAnchor
            ),
            backW,
            backH,

            macSearchField.leadingAnchor.constraint(
                equalTo: macBackButton.trailingAnchor,
                constant: 12
            ),
            macSearchField.trailingAnchor.constraint(
                equalTo: macChrome.trailingAnchor,
                constant: -16
            ),
            macSearchField.centerYAnchor.constraint(
                equalTo: macChrome.centerYAnchor
            ),
            fieldH,
            equalHeights
        ])
    }

    private func makeSearchFieldIconView(height: CGFloat) -> UIView {
        // Keep leftView short so it doesn't zero-out the text rect height.
        let wrap = UIView(frame: CGRect(x: 0, y: 0, width: 34, height: height))
        let icon = UIImageView(frame: CGRect(x: 10, y: 0, width: 16, height: height))
        if #available(iOS 13.0, *) {
            let cfg = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
            icon.image = UIImage(systemName: "magnifyingglass", withConfiguration: cfg)
        }
        icon.contentMode = .scaleAspectFit
        icon.tintColor = UIColor(white: 0.7, alpha: 1)
        wrap.addSubview(icon)
        return wrap
    }

    @objc
    private func macBackTapped() {
        navigationController?.popViewController(animated: true)
    }

    @objc
    private func macSearchFieldChanged() {
        // Do not rewrite attributedText while IME has marked range — that
        // kills Chinese composition. Only re-assert colors.
        macSearchField.applyVisibleTextAppearance(
            isDark: ThemeManager.shared.isDark
        )
        let text = macSearchField.text ?? ""
        if text.isEmpty, macSearchField.markedTextRange == nil {
            clearSearchResults()
        }
        updatePanel(for: text)
    }

    private func setupSearchBar() {
        searchBar.delegate = self
        searchBar.placeholder = "Search YouTube"
        searchBar.text = lastQuery.isEmpty ? nil : lastQuery
        searchBar.autocapitalizationType = .none
        searchBar.autocorrectionType = .no
        searchBar.returnKeyType = .search
        searchBar.searchBarStyle = .minimal
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(searchBar)
        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor
            ),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    private func setupTableView() {
        tableView.register(
            SubscriptionVideoCell.self,
            forCellReuseIdentifier: SubscriptionVideoCell.reuseId
        )
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = PlatformStyle.isMac ? 140 : 320
        tableView.separatorInset = UIEdgeInsets(
            top: 0, left: 12, bottom: 0, right: 12
        )
        tableView.translatesAutoresizingMaskIntoConstraints = false
        refreshControl.addTarget(
            self,
            action: #selector(handleRefresh),
            for: .valueChanged
        )
        tableView.refreshControl = PlatformStyle.isMac ? nil : refreshControl
        view.addSubview(tableView)
        activateTableConstraints()
    }

    private func activateTableConstraints() {
        if PlatformStyle.isMac {
            NSLayoutConstraint.activate([
                tableView.topAnchor.constraint(equalTo: macChrome.bottomAnchor),
                tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
        } else {
            NSLayoutConstraint.activate([
                tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor),
                tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
        }
    }

    @objc
    private func applyTheme() {
        let theme = ThemeManager.shared
        view.backgroundColor = theme.background
        tableView.backgroundColor = theme.background
        tableView.separatorColor = theme.separator
        searchBar.barStyle = theme.barStyle
        searchBar.backgroundColor = .clear
        searchBar.barTintColor = theme.background
        searchBar.keyboardAppearance = theme.isDark ? .dark : .default
        if PlatformStyle.isMac {
            applyMacSearchTheme(theme)
        } else if let nav = navigationController {
            GlassChrome.apply(to: nav.navigationBar, theme: theme)
        }
        tableView.reloadData()
    }

    @objc
    private func handleRefresh() {
        guard !lastQuery.isEmpty else {
            refreshControl.endRefreshing()
            return
        }
        search(query: lastQuery)
    }

    /// Active query text for both platforms.
    var currentSearchText: String {
        if PlatformStyle.isMac {
            return macSearchField.text ?? ""
        }
        return searchBar.text ?? ""
    }

    /// Theme-aware Mac search chrome — force visible typed + IME marked text.
    private func applyMacSearchTheme(_ theme: ThemeManager) {
        macChrome.backgroundColor = theme.background
        NavChevron.applyMacFloatingStyle(
            to: macBackButton,
            kind: .back,
            theme: theme,
            side: ResponsiveMetrics.macSearchControlHeight()
        )
        macSearchField.applyVisibleTextAppearance(isDark: theme.isDark)
    }
}

// MARK: - UISearchBarDelegate (iOS)

extension SearchViewController: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        guard let query = searchBar.text, !query.isEmpty else {
            return
        }
        searchBar.resignFirstResponder()
        search(query: query)
    }

    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        if !PlatformStyle.isMac {
            searchBar.setShowsCancelButton(true, animated: true)
        }
        updatePanel(for: searchBar.text ?? "")
    }

    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        if !PlatformStyle.isMac {
            searchBar.setShowsCancelButton(false, animated: true)
        }
        setPanel(.hidden)
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }

    func searchBar(
        _ searchBar: UISearchBar,
        textDidChange searchText: String
    ) {
        if searchText.isEmpty {
            clearSearchResults()
        }
        updatePanel(for: searchText)
    }
}

// MARK: - UITextFieldDelegate (Mac)

extension SearchViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        guard let query = textField.text, !query.isEmpty else {
            return false
        }
        textField.resignFirstResponder()
        search(query: query)
        return true
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        updatePanel(for: textField.text ?? "")
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        setPanel(.hidden)
    }
}
