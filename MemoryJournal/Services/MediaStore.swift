//
//  MediaStore.swift
//  MemoryJournal
//
//  Where photos and voice notes live: inside the app's OWN container on this
//  device. The privacy rule (CLAUDE.md) is that the SwiftData entry stores only
//  a *filename*, and the bytes live here on disk — never in the database, never
//  off-device.
//
//  Files go under Application Support (the app's private area, not visible in
//  the Files app, not synced anywhere by us):
//      …/Application Support/Media/Photos/<uuid>.jpg
//      …/Application Support/Media/Audio/<uuid>.m4a
//
//  Phase 3A only needs to *read* (render a row's thumbnail). Writing real photos
//  is Part C and audio is Part D; the small DEBUG image writer below just lets
//  the seeded sample data show a real thumbnail.
//

import Foundation
import UIKit

enum MediaStore {
    // MARK: - Locations

    private static var mediaRoot: URL {
        URL.applicationSupportDirectory.appendingPathComponent("Media", isDirectory: true)
    }
    static var photosDirectory: URL { mediaRoot.appendingPathComponent("Photos", isDirectory: true) }
    static var audioDirectory: URL { mediaRoot.appendingPathComponent("Audio", isDirectory: true) }

    static func photoURL(_ filename: String) -> URL { photosDirectory.appendingPathComponent(filename) }
    static func audioURL(_ filename: String) -> URL { audioDirectory.appendingPathComponent(filename) }

    /// Make sure the directories exist before reading/writing. Safe to call repeatedly.
    static func ensureDirectories() {
        let fm = FileManager.default
        try? fm.createDirectory(at: photosDirectory, withIntermediateDirectories: true)
        try? fm.createDirectory(at: audioDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Reading

    /// Load a photo by filename, or `nil` if the file is missing (e.g. seeded
    /// data that points at a file we haven't written). Callers should show a
    /// placeholder when this returns `nil`.
    static func loadPhoto(_ filename: String) -> UIImage? {
        UIImage(contentsOfFile: photoURL(filename).path)
    }

    static func audioExists(_ filename: String) -> Bool {
        FileManager.default.fileExists(atPath: audioURL(filename).path)
    }

    #if DEBUG
    /// Write a simple gradient JPEG into the Photos directory so the seeded
    /// sample entries render a real thumbnail. DEBUG-only; not in release builds.
    static func writeSampleImage(filename: String, top: UIColor, bottom: UIColor) {
        ensureDirectories()
        let url = photoURL(filename)
        guard !FileManager.default.fileExists(atPath: url.path) else { return }

        let size = CGSize(width: 400, height: 600)
        let image = UIGraphicsImageRenderer(size: size).image { context in
            let cg = context.cgContext
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [top.cgColor, bottom.cgColor] as CFArray,
                locations: [0, 1]
            )!
            cg.drawLinearGradient(gradient,
                                  start: .zero,
                                  end: CGPoint(x: size.width, y: size.height),
                                  options: [])
        }
        if let data = image.jpegData(compressionQuality: 0.85) {
            try? data.write(to: url)
        }
    }
    #endif
}
