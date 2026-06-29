import ImageIO
import UIKit

extension ThumbnailImageView {
    // MARK: - Prefetch

    static func prefetch(url: URL) {
        let key = url.absoluteString
        guard cache.object(forKey: key) == nil else {
            return
        }
        DispatchQueue.global(qos: .utility).async {
            if let cached = loadFromDiskCache(
                url: url, key: key
            ) {
                return
            }
            fetchAndCache(url: url, key: key)
        }
    }

    // MARK: - Downsampling

    static func downsample(
        imageAt fileURL: URL,
        to maxPixelSize: Int
    ) -> UIImage? {
        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: false
        ]
        guard let src = CGImageSourceCreateWithURL(
            fileURL as CFURL,
            options as CFDictionary
        ) else {
            return nil
        }
        return makeThumbnail(from: src, to: maxPixelSize)
    }

    static func downsample(
        data: Data,
        to maxPixelSize: Int
    ) -> UIImage? {
        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: false
        ]
        guard let src = CGImageSourceCreateWithData(
            data as CFData,
            options as CFDictionary
        ) else {
            return nil
        }
        return makeThumbnail(from: src, to: maxPixelSize)
    }

    // MARK: - Private

    private static func loadFromDiskCache(
        url: URL,
        key: String
    ) -> UIImage? {
        guard cachingEnabled,
              let fileURL = diskCache.fileURL(for: url)
        else {
            return nil
        }
        guard let img = downsample(
            imageAt: fileURL,
            to: 640
        ) else {
            return nil
        }
        cache.setObject(
            img,
            forKey: key,
            cost: img.memoryCost
        )
        return img
    }

    private static func fetchAndCache(
        url: URL,
        key: String
    ) {
        let task = URLSession.shared.dataTask(
            with: url
        ) { data, _, _ in
            guard let data else {
                return
            }
            if let img = downsample(data: data, to: 640) {
                cache.setObject(
                    img,
                    forKey: key,
                    cost: img.memoryCost
                )
            }
            if cachingEnabled {
                diskCache.store(data: data, for: url)
            }
        }
        task.resume()
    }

    private static func makeThumbnail(
        from src: CGImageSource,
        to maxPixelSize: Int
    ) -> UIImage? {
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(
            src, 0, opts as CFDictionary
        ) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}
