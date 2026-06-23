//
//  ComposerView.swift
//  MemoryJournal
//
//  The composer for TODAY's entry. Presented as a sheet from Home. Works in two
//  modes from one screen:
//    • create — `existingEntry == nil`: a fresh entry for `date`.
//    • edit   — `existingEntry != nil`: load that entry's title/body/media and update.
//
//  Save rule (confirmed with owner): an entry needs ANY real content — body
//  text, at least one photo, or a voice note (`Entry.hasSavableContent`). Title
//  is optional and never enough on its own.
//
//  Dismiss rule: swiping the sheet away AUTO-SAVES when there's savable content
//  (like Apple Notes), so a draft is never silently lost. With nothing to save,
//  dismissing just cleans up. There is no separate Cancel button.
//
//  Photos (Part C): up to 3, library (PhotosPicker, no permission) or camera
//  (needs permission). Voice (Part D): ONE voice note per entry, via the mic
//  flow (record → review → keep). All media is copied into the app container;
//  only FILENAMES are stored on the entry — never bytes, never off-device. Files
//  are committed on Save and cleaned up on cancel so nothing is orphaned.
//

import SwiftUI
import SwiftData
import PhotosUI

struct ComposerView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(VoicePlayer.self) private var player

    let date: Date
    var existingEntry: Entry?
    /// When opened from the Prompts screen, the chosen prompt to seed the title.
    var prompt: String?
    /// Called after a successful save (before dismiss). Lets the caller react —
    /// e.g. the Prompts screen jumps to Home so the new entry is visible.
    var onSaved: (() -> Void)?

    @State private var title: String = ""
    @State private var bodyText: String = ""
    @State private var appliedPrompt: String?   // the prompt that actually seeded this entry

    @FocusState private var bodyFocused: Bool

    // Photos
    private let maxPhotos = 3
    @State private var photoFilenames: [String] = []
    @State private var originalPhotoFilenames: [String] = []
    @State private var sessionFiles: Set<String> = []            // photo files written this session
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showPhotoPicker = false
    @State private var showCamera = false
    @State private var cameraDeniedAlert = false
    @State private var cameraUnavailableAlert = false

    // Voice (one per entry)
    @State private var recorder = VoiceRecorder()
    @State private var voiceFilename: String?                    // attached voice note (what will be saved)
    @State private var originalVoiceFilename: String?
    @State private var audioSessionFiles: Set<String> = []       // audio files written this session
    @State private var micDeniedAlert = false

    @State private var didSave = false
    @State private var didDelete = false   // deleted the entry → don't auto-save on dismiss

    private var canSave: Bool {
        Entry.hasSavableContent(body: bodyText,
                                photoCount: photoFilenames.count,
                                hasAudio: voiceFilename != nil)
    }
    private var canAddPhotos: Bool { photoFilenames.count < maxPhotos }
    private var canRecord: Bool { voiceFilename == nil && recorder.phase == .idle }

    var body: some View {
        VStack(spacing: Spacing.md) {
            // Date, title, body and media scroll together; the toolbar + the
            // action bar stay pinned below (the keyboard pushes them up).
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
                    if let voiceFilename {
                        VoiceNotePlayerBar(filename: voiceFilename, onRemove: removeVoice)
                            .padding(.top, Spacing.lg)
                    }

                    // Edit mode only: delete today's entry (gated by a confirmation).
                    if existingEntry != nil {
                        HStack {
                            Spacer()
                            DeleteMemoryButton(onConfirm: deleteEntry)
                            Spacer()
                        }
                        .padding(.top, Spacing.xl)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.xl)
                .padding(.top, Spacing.lg)
            }

            mediaToolbar
                .padding(.horizontal, Spacing.xl)

            actionBar
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
        .alert("Microphone Access Needed", isPresented: $micDeniedAlert) {
            Button("Open Settings") { openSettings() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("To record a voice note, turn on microphone access for Memory Journal in Settings.")
        }
        .onAppear {
            if let entry = existingEntry {
                title = entry.title ?? ""
                bodyText = entry.body
                photoFilenames = entry.photoFilenames
                originalPhotoFilenames = entry.photoFilenames
                voiceFilename = entry.voiceNoteFilename
                originalVoiceFilename = entry.voiceNoteFilename
            }
            // Seed the title from a prompt, but only if there isn't a title already
            // (never clobber what the user wrote when editing today's entry).
            if let prompt, title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                title = prompt
                appliedPrompt = prompt
            }
            #if DEBUG
            if CommandLine.arguments.contains("-focusBody") {
                Task { @MainActor in bodyFocused = true }
            }
            if CommandLine.arguments.contains("-voiceRecording") {
                recorder.debugEnter(.recording)
            }
            if CommandLine.arguments.contains("-voiceReview") {
                recorder.debugEnter(.reviewing, filename: "debug.m4a")
            }
            #endif
        }
        .onDisappear(perform: handleDismiss)
    }

    // MARK: - Title (single line, custom-coloured placeholder)

    private var titleField: some View {
        // `axis: .vertical` lets the title wrap to multiple lines — needed for
        // long prompt-titles (e.g. a full question), and better for long manual
        // titles too. Short titles still render on one line.
        TextField("", text: $title, axis: .vertical)
            .font(.kyoto(size: 32))
            .foregroundStyle(Color.appPrimary)
            .tint(Color.appPrimary)
            .overlay(alignment: .topLeading) {
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
            toolbarIcon("mic", enabled: canRecord) { tapMic() }
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

    // MARK: - Action bar (Save, or the recording / review bars)

    @ViewBuilder
    private var actionBar: some View {
        switch recorder.phase {
        case .idle:
            AppButton(title: "Save your memory", action: save)
                .opacity(canSave ? 1 : 0.45)
                .disabled(!canSave)
        case .recording:
            RecordingBar(elapsed: recorder.elapsed, levels: recorder.liveLevels) {
                recorder.stop()
            }
        case .reviewing:
            if let take = recorder.recordedFilename {
                ReviewBar(filename: take,
                          levels: recorder.capturedWaveform,
                          onDiscard: { player.stop(); recorder.discard() },
                          onConfirm: confirmVoice)
            }
        }
    }

    // MARK: - Photo actions

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
            case .granted: showCamera = true
            case .notDetermined:
                if await MediaPermissions.request(.camera) == .granted { showCamera = true }
                else { cameraDeniedAlert = true }
            case .denied: cameraDeniedAlert = true
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
        pickerItems = []
    }

    private func addCaptured(_ image: UIImage) {
        guard photoFilenames.count < maxPhotos,
              let filename = MediaStore.savePhoto(image) else { return }
        photoFilenames.append(filename)
        sessionFiles.insert(filename)
    }

    private func removePhoto(_ filename: String) {
        photoFilenames.removeAll { $0 == filename }   // file cleaned up on save/cancel
    }

    // MARK: - Voice actions

    private func tapMic() {
        guard canRecord else { return }
        Task { @MainActor in
            switch MediaPermissions.status(of: .microphone) {
            case .granted: startRecording()
            case .notDetermined:
                if await MediaPermissions.request(.microphone) == .granted { startRecording() }
                else { micDeniedAlert = true }
            case .denied: micDeniedAlert = true
            }
        }
    }

    private func startRecording() {
        bodyFocused = false        // drop the keyboard so the recording bar is visible
        try? recorder.start()
    }

    private func confirmVoice() {
        player.stop()
        if let filename = recorder.confirm() {
            voiceFilename = filename
            audioSessionFiles.insert(filename)
        }
    }

    private func removeVoice() {
        player.stop()
        voiceFilename = nil        // file cleaned up on save/cancel
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - Save / cleanup

    private func save() {
        guard canSave else { return }
        let cleaned = Entry.cleanedInput(title: title, body: bodyText)
        let finalPhotos = photoFilenames
        let finalVoice = voiceFilename

        if let entry = existingEntry {
            entry.title = cleaned.title
            entry.body = cleaned.body
            entry.photoFilenames = finalPhotos
            entry.voiceNoteFilename = finalVoice
            if let appliedPrompt { entry.promptUsed = appliedPrompt }
            entry.modifiedAt = .now
        } else {
            context.insert(Entry(date: date,
                                 title: cleaned.title,
                                 body: cleaned.body,
                                 photoFilenames: finalPhotos,
                                 voiceNoteFilename: finalVoice,
                                 promptUsed: appliedPrompt))
        }
        try? context.save()

        // Delete media no longer referenced by the saved entry.
        for filename in MediaStore.orphanedFiles(original: originalPhotoFilenames,
                                                 session: sessionFiles,
                                                 final: finalPhotos) {
            MediaStore.deletePhoto(filename)
        }
        for filename in MediaStore.orphanedFiles(original: [originalVoiceFilename].compactMap { $0 },
                                                 session: audioSessionFiles,
                                                 final: [finalVoice].compactMap { $0 }) {
            MediaStore.deleteAudio(filename)
        }

        didSave = true
        onSaved?()
        dismiss()
    }

    /// Delete the entry being edited (today's entry) and everything it owns,
    /// including anything added in this session. Only available in edit mode.
    private func deleteEntry() {
        guard let entry = existingEntry else { return }
        player.stop()
        if recorder.phase != .idle { recorder.discard() }
        // Files written this session that won't be kept.
        for filename in sessionFiles { MediaStore.deletePhoto(filename) }
        for filename in audioSessionFiles { MediaStore.deleteAudio(filename) }
        entry.deleteWithMedia(in: context)
        didDelete = true   // so handleDismiss doesn't auto-save on the way out
        dismiss()
    }

    private func handleDismiss() {
        // The explicit Save button saved + cleaned up; delete tore everything down.
        guard !didSave, !didDelete else { return }
        player.stop()
        // A recording that was never "kept" (still recording or in review) isn't
        // part of the entry — abandon it before deciding whether to save.
        if recorder.phase != .idle { recorder.discard() }

        if canSave {
            // Swiped away with content → auto-save so the draft is never lost.
            save()
        } else {
            // Nothing worth keeping — drop anything written this session.
            // (Original files on an edited entry are untouched.)
            for filename in sessionFiles { MediaStore.deletePhoto(filename) }
            for filename in audioSessionFiles { MediaStore.deleteAudio(filename) }
        }
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
            .aspectRatio(110.0 / 140.0, contentMode: .fit)
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
                    .padding(6)
                }
                .accessibilityLabel("Remove photo")
            }
    }
}

#Preview {
    ComposerView(date: .now)
        .modelContainer(for: Entry.self, inMemory: true)
        .environment(VoicePlayer())
}
