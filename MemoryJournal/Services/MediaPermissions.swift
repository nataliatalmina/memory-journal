//
//  MediaPermissions.swift
//  MemoryJournal
//
//  Thin wrapper around the three system permission APIs the app uses. It ONLY
//  asks iOS for authorization and reads the current status — it never reads,
//  copies, stores, or transmits any media. (Honesty rule from CLAUDE.md: the
//  onboarding copy promises we don't store your media or personal data.)
//
//  The three underlying APIs:
//   • Camera       → AVCaptureDevice   (AVFoundation)
//   • Microphone   → AVAudioApplication (AVFoundation, iOS 17+ API)
//   • Photo library → PHPhotoLibrary    (Photos)
//
//  ON THE PHOTO LIBRARY — read this before changing it. This app spent a release
//  with NO photo-library capability, because *attaching* a photo needs none:
//  `PhotosPicker` runs out-of-process and hands back only the images the user
//  picked. Requesting access the app never used is what got build 1.0 (3)
//  rejected under guideline 5.1.1(iv).
//
//  Photo look-back is different: it searches the library by capture date, which
//  no out-of-process picker can do, so it needs real access. That's access the
//  app genuinely uses, which is exactly what the guideline asks for. Attaching
//  still goes through `PhotosPicker` and still needs no permission.
//
//  The prompt is raised ONLY by the user tapping the in-context card on the
//  Journal screen. Nothing in onboarding may trigger it, and no screen may
//  explain it beforehand — see CLAUDE.md → "Permission requests".
//
//  Note we ask for `.readWrite` even though the app only ever reads. The Photos
//  framework has no read-only access level: `PHAccessLevel` is `.addOnly` or
//  `.readWrite`, and `.addOnly` is write-only. `.readWrite` is the narrowest
//  level that can read, so it's the honest choice — we simply never write.
//
//  Each iOS permission has the same lifecycle: it starts "not determined", the
//  first request shows the system prompt, and the user's answer ("granted" or
//  "denied") is remembered by iOS forever after. You can only prompt once; if
//  the user later wants to change their mind they do it in the Settings app,
//  which is why "denied" sends them there.
//

import AVFoundation
import Photos

/// The capabilities we can request.
enum MediaCapability: CaseIterable, Identifiable {
    case camera
    case microphone
    case photoLibrary

    var id: Self { self }
}

/// Our own simplified view of any permission. Each system API has its own status
/// enum with extra cases (`.restricted`, `.limited`); we fold those into these
/// four, because these are the only distinctions the UI actually acts on.
enum PermissionStatus {
    case notDetermined   // never asked yet → tapping will show the system prompt
    case granted         // allowed
    case denied          // refused or restricted → must change in Settings

    /// Photo library only: the user chose "Selected Photos" — we can see the
    /// handful they picked and nothing else.
    ///
    /// This deserves its own case rather than folding into `.granted` or
    /// `.denied`, because it fails in a way that looks like neither. Photo
    /// look-back searches the whole library by date; with limited access it
    /// searches a handful of photos, finds nothing on most dates, and renders an
    /// empty screen that is indistinguishable from "you took no photos that day".
    /// The user is owed an explanation, so the UI has to be able to tell.
    case limited
}

@MainActor
enum MediaPermissions {

    /// Read the CURRENT status without prompting. Used to render each button's
    /// state when the screen appears.
    static func status(of capability: MediaCapability) -> PermissionStatus {
        switch capability {
        case .camera:
            return map(AVCaptureDevice.authorizationStatus(for: .video))
        case .microphone:
            return map(AVAudioApplication.shared.recordPermission)
        case .photoLibrary:
            return map(PHPhotoLibrary.authorizationStatus(for: .readWrite))
        }
    }

    /// Ask iOS for the permission. Shows the system prompt only the first time;
    /// afterwards it returns the existing decision immediately. `async` because
    /// we wait for the user's tap on the system dialog without blocking the UI.
    static func request(_ capability: MediaCapability) async -> PermissionStatus {
        switch capability {
        case .camera:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            return granted ? .granted : .denied

        case .microphone:
            // `requestRecordPermission` uses a completion handler; we wrap it in
            // `withCheckedContinuation` to expose it as a clean `async` call.
            let granted = await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
            return granted ? .granted : .denied

        case .photoLibrary:
            // `.readWrite` because the framework has no read-only level (see the
            // file header). The user may answer "Limited", which is neither yes
            // nor no and is why `PermissionStatus` has a `.limited` case.
            return map(await PHPhotoLibrary.requestAuthorization(for: .readWrite))
        }
    }

    // MARK: - Map each system enum into our own PermissionStatus

    private static func map(_ status: AVAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .authorized:    .granted
        case .notDetermined: .notDetermined
        default:             .denied   // .denied, .restricted
        }
    }

    private static func map(_ status: AVAudioApplication.recordPermission) -> PermissionStatus {
        switch status {
        case .granted:      .granted
        case .undetermined: .notDetermined
        default:            .denied   // .denied
        }
    }

    private static func map(_ status: PHAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .authorized:    .granted
        case .limited:       .limited        // "Selected Photos" — kept distinct on purpose
        case .notDetermined: .notDetermined
        default:             .denied         // .denied, .restricted
        }
    }
}
