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

    // MARK: - Writing photos

    /// Save a photo into the app container as a JPEG and return its filename.
    /// Large images are downscaled so we don't store full-resolution originals.
    /// Returns `nil` if encoding/writing fails.
    @discardableResult
    static func savePhoto(_ image: UIImage, maxDimension: CGFloat = 2048, quality: CGFloat = 0.85) -> String? {
        ensureDirectories()
        let scaled = downscaled(image, maxDimension: maxDimension)
        guard let data = scaled.jpegData(compressionQuality: quality) else { return nil }
        let filename = "\(UUID().uuidString).jpg"
        do {
            try data.write(to: photoURL(filename), options: .atomic)
            return filename
        } catch {
            return nil
        }
    }

    /// Decode raw image data (e.g. from `PhotosPicker`) and save it.
    static func savePhotoData(_ data: Data) -> String? {
        guard let image = UIImage(data: data) else { return nil }
        return savePhoto(image)
    }

    /// Delete a photo file. Safe to call if it doesn't exist.
    static func deletePhoto(_ filename: String) {
        try? FileManager.default.removeItem(at: photoURL(filename))
    }

    /// After a composer save, which files should be deleted? Everything we had
    /// (`original`) or wrote this session (`session`) that the saved entry no
    /// longer references (`final`). Pure set math — kept separate so it can be
    /// unit-tested (orphaned media would quietly violate the privacy promise).
    static func orphanedPhotoFiles(original: [String], session: Set<String>, final: [String]) -> Set<String> {
        Set(original).union(session).subtracting(final)
    }

    /// Shrink an image so its longest edge is at most `maxDimension`, preserving
    /// aspect ratio. Returns the original if it's already small enough.
    private static func downscaled(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let longest = max(image.size.width, image.size.height)
        guard longest > maxDimension else { return image }
        let scale = maxDimension / longest
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        return UIGraphicsImageRenderer(size: newSize).image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
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
