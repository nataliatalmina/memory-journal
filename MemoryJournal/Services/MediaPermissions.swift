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
//   • Camera     → AVCaptureDevice  (AVFoundation)
//   • Microphone → AVAudioApplication (AVFoundation, iOS 17+ API)
//
//  There is deliberately NO photo-library capability here. Photos are attached
//  with `PhotosPicker`, which runs out-of-process and hands back only the images
//  the user picked, so it needs no authorization at all. The app used to request
//  `PHPhotoLibrary` access it never actually used — that was removed after App
//  Review flagged the onboarding permission screen under guideline 5.1.1(iv).
//
//  Each iOS permission has the same lifecycle: it starts "not determined", the
//  first request shows the system prompt, and the user's answer ("granted" or
//  "denied") is remembered by iOS forever after. You can only prompt once; if
//  the user later wants to change their mind they do it in the Settings app,
//  which is why "denied" sends them there.
//

import AVFoundation

/// The three capabilities we can request.
enum MediaCapability: CaseIterable, Identifiable {
    case camera
    case microphone

    var id: Self { self }
}

/// Our own simplified, three-state view of any permission. (Each system API has
/// its own status enum with extra cases like `.restricted` / `.limited`; we fold
/// those into these three because the UI only needs to know "ask / good / blocked".)
enum PermissionStatus {
    case notDetermined   // never asked yet → tapping will show the system prompt
    case granted         // allowed
    case denied          // refused or restricted → must change in Settings
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
        }
    }

    // MARK: - Map each system enum into our three-state PermissionStatus

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
}
