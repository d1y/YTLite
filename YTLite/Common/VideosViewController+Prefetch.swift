import UIKit

extension VideosViewController: UICollectionViewDataSourcePrefetching {
    func collectionView(
        _ collectionView: UICollectionView,
        prefetchItemsAt indexPaths: [IndexPath]
    ) {
        guard !isLoadingInitial else {
            return
        }
        for indexPath in indexPaths {
            guard indexPath.item < videos.count else {
                continue
            }
            let video = videos[indexPath.item]
            if let url = URL(string: video.thumbnailURL) {
                ThumbnailImageView.prefetch(url: url)
            }
        }
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cancelPrefetchingForItemsAt indexPaths: [IndexPath]
    ) {}
}
