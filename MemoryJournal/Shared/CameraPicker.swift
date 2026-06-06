//
//  CameraPicker.swift
//  MemoryJournal
//
//  A thin wrapper around UIKit's `UIImagePickerController` in camera mode. There
//  is no pure-SwiftUI camera capture, and CLAUDE.md explicitly allows UIKit for
//  media pickers — so we wrap it cleanly here with `UIViewControllerRepresentable`
//  (the bridge that lets a UIKit view controller appear inside SwiftUI).
//
//  It captures a single still image and hands it back via `onCapture`. The
//  picker never touches the photo library and stores nothing itself — the caller
//  decides where the image goes (into the app container, via MediaStore).
//
//  Note: the camera is unavailable in the iOS Simulator, so this is only
//  exercisable on a real device.
//

import SwiftUI
import UIKit

struct CameraPicker: UIViewControllerRepresentable {
    /// Called with the captured photo when the user takes one.
    var onCapture: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    // The Coordinator receives the UIKit delegate callbacks and forwards them.
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onCapture(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
