//
//  ComposerView.swift
//  MemoryJournal
//
//  The composer for TODAY's entry. Presented as a sheet from Home. Works in two
//  modes from one screen:
//    • create — `existingEntry == nil`: a fresh entry for `date`.
//    • edit   — `existingEntry != nil`: load that entry's title/body/photos and update.
//
//  Save rule (confirmed with owner): an entry needs non-whitespace BODY text.
//  Title is optional. Photos/voice don't change that rule.
//
//  Photos (Part C): up to 3, from the library (PhotosPicker — needs no permission)
//  or the camera (needs camera permission). Images are copied into the app
//  container (MediaStore); only the FILENAMES are stored on the entry — never
//  raw bytes, never off-device. Files are committed on Save and cleaned up on
//  cancel so nothing is orphaned.
//
//  Voice (mic) is Part D and still a placeholder.
//

import SwiftUI
import SwiftData
import PhotosUI

struct ComposerView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let date: Date
    var existingEntry: Entry?

    @State private var title: String = ""
    @State private var bodyText: String = ""
    @FocusState private var bodyFocused: Bool

    // Photos
    private let maxPhotos = 3
    @State private var photoFilenames: [String] = []        // working list (what will be saved)
    @State private var originalPhotoFilenames: [String] = [] // snapshot on load (edit mode)
    @State private var sessionFiles: Set<String> = []        // files written to disk this session
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showPhotoPicker = false
    @State private var showCamera = false
    @State private var cameraDeniedAlert = false
    @State private var cameraUnavailableAlert = false
    @State private var didSave = false

    private var canSave: Bool { Entry.cleanedInput(title: title, body: bodyText) != nil }
    private var canAddPhotos: Bool { photoFilenames.count < maxPhotos }

    var body: some View {
        VStack(spacing: Spacing.md) {
            // Date, title, body and photos scroll together; the toolbar + Save stay
            // pinned below (and the keyboard pushes them up when typing).
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text(date.journalHeading())
                        .font(.kyoto(size: 20))
                        .foregroundStyle(Color.appBodyText)

                    titleField
                    bodyField

                    if !photoFilenames.isEmpty {
                        photoRow.padding(.top, Spacing.lg)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.xl)
                .padding(.top, Spacing.lg)
            }

            mediaToolbar
                .padding(.horizontal, Spacing.xl)

            AppButton(title: "Save your memory", action: save)
                .opacity(canSave ? 1 : 0.45)
                .disabled(!canSave)
                .padding(.horizontal, Spacing.xl)
                .padding(.bottom, Spacing.md)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appSurface)
        .photosPicker(isPresented: $showPhotoPicker,
                      selection: $pickerItems,
                      maxSelectionCount: max(1, maxPhotos - photoFilenames.count),
                      matching: .images)
        .onChange(of: pickerItems) { _, items in
            guard !items.isEmpty else { return }
            Task { await addPicked(items) }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { addCaptured($0) }
                .ignoresSafeArea()
        }
        .alert("Camera Access Needed", isPresented: $cameraDeniedAlert) {
            Button("Open Settings") { openSettings() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("To take a photo, turn on camera access for Memory Journal in Settings. You can still add photos from your library.")
        }
        .alert("Camera Unavailable", isPresented: $cameraUnavailableAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This device doesn't have a camera available.")
        }
        .onAppear {
            if let entry = existingEntry {
                title = entry.title ?? ""
                bodyText = entry.body
                photoFilenames = entry.photoFilenames
                originalPhotoFilenames = entry.photoFilenames
            }
            #if DEBUG
            if CommandLine.arguments.contains("-focusBody") {
                Task { @MainActor in bodyFocused = true }
            }
            #endif
        }
        .onDisappear {
            // If we left WITHOUT saving (swipe-to-dismiss), drop any files added
            // this session — they were never committed to an entry.
            if !didSave {
                for filename in sessionFiles { MediaStore.deletePhoto(filename) }
            }
        }
    }

    // MARK: - Title (single line, custom-coloured placeholder)

    private var titleField: some View {
        TextField("", text: $title)
            .font(.kyoto(size: 32))
            .foregroundStyle(Color.appPrimary)
            .tint(Color.appPrimary)
            .overlay(alignment: .leading) {
                if title.isEmpty {
                    Text("Title your entry")
                        .font(.kyoto(size: 32))
                        .foregroundStyle(Color.appPrimary.opacity(0.6))
                        .allowsHitTesting(false)
                }
            }
    }

    // MARK: - Body (multi-line, grows with content, custom placeholder)

    private var bodyField: some View {
        // `axis: .vertical` makes the field grow downward as you type (no inner
        // scroll), so it sits naturally above the photos inside the ScrollView.
        ZStack(alignment: .topLeading) {
            if bodyText.isEmpty {
                Text("Write about something you want to remember....")
                    .font(.kyotoItalic(size: 18))
                    .foregroundStyle(Color.appBodyText.opacity(0.8))
                    .allowsHitTesting(false)
            }
            TextField("", text: $bodyText, axis: .vertical)
                .font(.kyoto(size: 18))
                .foregroundStyle(Color.appBodyText)
                .tint(Color.appPrimary)
                .focused($bodyFocused)
        }
    }

    // MARK: - Photos

    private var photoRow: some View {
        // Three equal slots so the thumbnails fit any screen width; filled slots
        // show a thumbnail, empty slots are invisible spacers (keeps 1–2 photos
        // left-aligned at the same size, matching the design).
        HStack(spacing: Spacing.md) {
            ForEach(0..<maxPhotos, id: \.self) { index in
                if index < photoFilenames.count {
                    let filename = photoFilenames[index]
                    EditablePhotoThumbnail(filename: filename) { removePhoto(filename) }
                        .frame(maxWidth: .infinity)
                } else {
                    Color.clear
                        .frame(maxWidth: .infinity)
                        .aspectRatio(110.0 / 140.0, contentMode: .fit)
                }
            }
        }
    }

    // MARK: - Media toolbar

    private var mediaToolbar: some View {
        // 44×44pt tap targets sitting adjacent (Messages-style density).
        HStack(spacing: 0) {
            Spacer()
            toolbarIcon("camera", enabled: canAddPhotos) { tapCamera() }
            toolbarIcon("photo", enabled: canAddPhotos) { tapPhoto() }
            toolbarIcon("mic", enabled: true) { /* TODO(Part D): record a voice note */ }
        }
    }

    private func toolbarIcon(_ systemName: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 22))
                .foregroundStyle(Color.appPrimary)
                .frame(width: 44, height: 44)
        }
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
    }

    // MARK: - Actions

    private func tapPhoto() {
        if canAddPhotos { showPhotoPicker = true }
    }

    private func tapCamera() {
        guard canAddPhotos else { return }
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            cameraUnavailableAlert = true
            return
        }
        Task { @MainActor in
            switch MediaPermissions.status(of: .camera) {
            case .granted:
                showCamera = true
            case .notDetermined:
                if await MediaPermissions.request(.camera) == .granted {
                    showCamera = true
                } else {
                    cameraDeniedAlert = true
                }
            case .denied:
                cameraDeniedAlert = true
            }
        }
    }

    private func addPicked(_ items: [PhotosPickerItem]) async {
        for item in items {
            guard photoFilenames.count < maxPhotos else { break }
            if let data = try? await item.loadTransferable(type: Data.self),
               let filename = MediaStore.savePhotoData(data) {
                photoFilenames.append(filename)
                sessionFiles.insert(filename)
            }
        }
        pickerItems = []   // reset so the same photo can be re-picked later
    }

    private func addCaptured(_ image: UIImage) {
        guard photoFilenames.count < maxPhotos,
              let filename = MediaStore.savePhoto(image) else { return }
        photoFilenames.append(filename)
        sessionFiles.insert(filename)
    }

    private func removePhoto(_ filename: String) {
        // Remove from the working list now; the file on disk is cleaned up on
        // Save (or on cancel) so we never delete something still referenced.
        photoFilenames.removeAll { $0 == filename }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - Save

    private func save() {
        guard let cleaned = Entry.cleanedInput(title: title, body: bodyText) else { return }
        let finalPhotos = photoFilenames

        if let entry = existingEntry {
            entry.title = cleaned.title
            entry.body = cleaned.body
            entry.photoFilenames = finalPhotos
            entry.modifiedAt = .now
        } else {
            context.insert(Entry(date: date,
                                 title: cleaned.title,
                                 body: cleaned.body,
                                 photoFilenames: finalPhotos))
        }
        try? context.save()

        // Delete files no longer referenced: removed originals + added-then-removed.
        for filename in MediaStore.orphanedPhotoFiles(original: originalPhotoFilenames,
                                                      session: sessionFiles,
                                                      final: finalPhotos) {
            MediaStore.deletePhoto(filename)
        }

        didSave = true
        dismiss()   // back to Home, which auto-updates via @Query
    }
}

/// A composer photo thumbnail with a ✕ remove button (our agreed interaction;
/// the static mockup shows only the added state).
private struct EditablePhotoThumbnail: View {
    let filename: String
    let onRemove: () -> Void

    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color.appSecondary.opacity(0.2))
            .aspectRatio(110.0 / 140.0, contentMode: .fit)   // matches the design's photo ratio
            .overlay {
                if let image = MediaStore.loadPhoto(filename) {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    Image(systemName: "photo").font(.title2).foregroundStyle(Color.appSecondary)
                }
            }
            .clipShape(.rect(cornerRadius: 6))
            .overlay(alignment: .topTrailing) {
                Button(action: onRemove) {
                    ZStack {
                        Circle().fill(Color.appPrimary)
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 22, height: 22)
                    .padding(6)   // larger hit area around the small ✕
                }
                .accessibilityLabel("Remove photo")
            }
    }
}

#Preview {
    ComposerView(date: .now)
        .modelContainer(for: Entry.self, inMemory: true)
}
