import UIKit

class ThumbnailImageView: UIImageView {
    static let cache = ImageMemoryCache()
    static let diskCache = ImageDiskCache()

    static var cachingEnabled: Bool {
        UserDefaults.standard.object(
            forKey: UserDefaultsKeys.Cache.imageCacheEnabled
        ) as? Bool ?? true
    }

    /// Maximum pixel dimension for downsampling.
    /// Thumbnails get 640, avatars get 96.
    var maxPixelSize: Int = 640

    private var currentURL: URL?
    private var loadToken: CancellationToken?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = ThemeManager.shared.thumbnailPlaceholder
        contentMode = .scaleAspectFill
        clipsToBounds = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    static func clearCache() {
        AppLog.img("clear all")
        cache.removeAll()
        diskCache.clear()
    }

    static func invalidate(url: String) {
        cache.remove(url: url)
        diskCache.remove(url: url)
    }

    func setImage(url: URL) {
        if currentURL == url,
           image != nil || loadToken != nil {
            return
        }
        loadToken?.cancel()
        loadToken = nil
        currentURL = url
        loadFromMemoryOrDisk(url: url)
    }

    func cancel() {
        loadToken?.cancel()
        loadToken = nil
        currentURL = nil
        image = nil
    }

    private func loadFromMemoryOrDisk(url: URL) {
        let key = url.absoluteString
        if let cached = ThumbnailImageView.cache.object(
            forKey: key
        ) {
            AppLog.img("mem-hit \(url.lastPathComponent)")
            image = cached
            loadToken = nil
            return
        }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self,
                  currentURL == url
            else {
                return
            }
            loadFromDiskOrNetwork(
                url: url, cacheKey: key
            )
        }
    }

    private func loadFromDiskOrNetwork(
        url: URL,
        cacheKey: String
    ) {
        if ThumbnailImageView.cachingEnabled,
           let fileURL = ThumbnailImageView.diskCache
               .fileURL(for: url) {
            handleDiskHit(
                url: url,
                fileURL: fileURL,
                cacheKey: cacheKey
            )
            return
        }
        clearImageOnMain(url: url)
        fetchFromNetwork(url: url, cacheKey: cacheKey)
    }

    private func handleDiskHit(
        url: URL,
        fileURL: URL,
        cacheKey: String
    ) {
        AppLog.img("disk-hit \(url.lastPathComponent)")
        let maxSz = maxPixelSize
        guard let img = ThumbnailImageView.downsample(
            imageAt: fileURL, to: maxSz
        ) else {
            return
        }
        ThumbnailImageView.cache.setObject(
            img,
            forKey: cacheKey,
            cost: img.memoryCost
        )
        DispatchQueue.main.async { [weak self] in
            guard self?.currentURL == url else {
                return
            }
            self?.loadToken = nil
            self?.image = img
        }
    }

    private func clearImageOnMain(url: URL) {
        DispatchQueue.main.async { [weak self] in
            guard self?.currentURL == url else {
                return
            }
            self?.image = nil
        }
    }

    private func fetchFromNetwork(
        url: URL,
        cacheKey: String
    ) {
        AppLog.img("fetch \(url.lastPathComponent)")
        let maxSz = maxPixelSize
        let token = CancellationToken()
        loadToken = token
        ServiceContainer.mediaTransport.send(
            HTTPRequest(method: .get, url: url),
            cancellationToken: token
        ) { [weak self] result in
            self?.handleNetworkResponse(
                data: try? result.get().data,
                url: url,
                cacheKey: cacheKey,
                maxPixelSize: maxSz
            )
        }
    }

    private func handleNetworkResponse(
        data: Data?,
        url: URL,
        cacheKey: String,
        maxPixelSize: Int
    ) {
        defer { clearTaskOnMain(url: url) }
        guard let data,
              currentURL == url
        else {
            return
        }
        cacheDownsampled(
            data: data,
            url: url,
            cacheKey: cacheKey,
            maxPixelSize: maxPixelSize
        )
        AppLog.img("stored \(url.lastPathComponent)")
    }

    private func clearTaskOnMain(url: URL) {
        DispatchQueue.main.async { [weak self] in
            guard self?.currentURL == url else {
                return
            }
            self?.loadToken = nil
        }
    }

    private func cacheDownsampled(
        data: Data,
        url: URL,
        cacheKey: String,
        maxPixelSize: Int
    ) {
        if let img = ThumbnailImageView.downsample(
            data: data, to: maxPixelSize
        ) {
            ThumbnailImageView.cache.setObject(
                img,
                forKey: cacheKey,
                cost: img.memoryCost
            )
        }
        if ThumbnailImageView.cachingEnabled {
            ThumbnailImageView.diskCache.store(
                data: data, for: url
            )
        }
        DispatchQueue.main.async { [weak self] in
            guard self?.currentURL == url else {
                return
            }
            self?.image = ThumbnailImageView.cache
                .object(forKey: cacheKey)
        }
    }
}
