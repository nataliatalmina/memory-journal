//
//  PhotoLibraryImage.swift
//  MemoryJournal
//
//  Renders a photo that lives in the USER'S photo library, addressed by its
//  Photos identifier. The sibling of `PhotoThumbnail` (EntryRow.swift), which
//  renders a photo the user attached to an entry and which therefore lives in
//  our own container.
//
//  The distinction matters and is the whole privacy story of photo look-back: an
//  attached photo was copied into the app when the user chose it; a look-back
//  photo is never copied at all. We hold an identifier, ask the system for a
//  bitmap to draw right now, and let it go. Nothing is written to disk, and
//  nothing about the photo is stored except — if the user dismisses it — its
//  identifier (see `PhotoDismissals`).
//

import SwiftUI
import Photos

struct PhotoLibraryImage: View {
    /// Photos' own reference to the asset, from `PhotoCandidate`.
    let localIdentifier: String
    /// How large this will be drawn, in points. Used to ask for a bitmap at
    /// roughly the right size rather than decoding a 12-megapixel original.
    let displaySize: CGSize

    // Loaded off the main thread, like `PhotoThumbnail` — these views sit in a
    // scrolling list that re-renders whenever the Journal screen's state changes,
    // and a synchronous decode there stutters both scrolling and sheet animations.
    @State private var state: LoadState = .loading

    private enum LoadState {
        case loading
        case loaded(UIImage)
        case unavailable
    }

    var body: some View {
        Group {
            switch state {
            case .loading:
                Color.appSecondary.opacity(0.12)

            case .loaded(let image):
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()

            case .unavailable:
                // The asset was deleted, or lives only in iCloud and couldn't be
                // fetched. A neutral placeholder, never an error — a missing photo
                // is not something the user did wrong.
                ZStack {
                    Color.appSecondary.opacity(0.25)
                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundStyle(Color.appSecondary)
                }
            }
        }
        .task(id: localIdentifier) {
            let image = await PhotoLibraryImageLoader.load(localIdentifier: localIdentifier,
                                                           displaySize: displaySize)
            state = image.map(LoadState.loaded) ?? .unavailable
        }
    }
}

/// Fetches a drawable bitmap for one library asset.
///
/// Kept separate from `PhotoLookback` on purpose: that service decides *which*
/// photo to show and touches only metadata, while this one asks for pixels. The
/// split is what lets the choosing logic be unit-tested without a photo library.
enum PhotoLibraryImageLoader {

    /// The bitmap for `localIdentifier`, or `nil` if it can't be produced.
    ///
    /// `nonisolated` so it can run off the main actor (this project is main-actor
    /// by default) — image decoding must never block the UI.
    nonisolated static func load(localIdentifier: String, displaySize: CGSize) async -> UIImage? {
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
        guard let asset = assets.firstObject else { return nil }

        let options = PHImageRequestOptions()

        // Allow iCloud downloads. Photos that aren't stored on the device would
        // otherwise come back as a blurry placeholder or nothing at all, which is
        // the common case for anyone with "Optimise iPhone Storage" on — i.e. most
        // people with a five-year-old photo. This is the system fetching the
        // user's own photo from their own iCloud; keepsake makes no network call
        // and the privacy promise is unaffected.
        options.isNetworkAccessAllowed = true

        // `.highQualityFormat` calls the completion handler EXACTLY ONCE. The
        // default `.opportunistic` calls back repeatedly (a degraded thumbnail
        // first, then the real thing), which would resume the continuation below
        // more than once — a crash, not a glitch.
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast

        // Photos wants pixels, not points. 3× covers the densest screens; asking
        // for a little too much costs some decode time, asking for too little
        // shows visibly soft edges.
        let pixelSize = CGSize(width: displaySize.width * 3, height: displaySize.height * 3)

        return await withCheckedContinuation { continuation in
            PHImageManager.default().requestImage(for: asset,
                                                  targetSize: pixelSize,
                                                  contentMode: .aspectFill,
                                                  options: options) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }
}
