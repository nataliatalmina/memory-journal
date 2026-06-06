//
//  MediaCleanupTests.swift
//  MemoryJournalTests
//
//  The composer's orphan-cleanup rule (Phase 3C): after a save, no photo file
//  should linger on disk unless the saved entry still references it. Stray media
//  would quietly break the "we don't keep your media" promise.
//

import Testing
@testable import MemoryJournal

struct MediaCleanupTests {

    @Test func removedOriginalPhotoIsDeleted() {
        // Edit removed "b" → it should be cleaned up.
        let orphans = MediaStore.orphanedFiles(original: ["a", "b"], session: [], final: ["a"])
        #expect(orphans == ["b"])
    }

    @Test func addedThenRemovedPhotoIsDeleted() {
        // Added "x" and "y" this session, then removed "y" before saving.
        let orphans = MediaStore.orphanedFiles(original: [], session: ["x", "y"], final: ["x"])
        #expect(orphans == ["y"])
    }

    @Test func keptPhotosAreNotDeleted() {
        let orphans = MediaStore.orphanedFiles(original: ["a"], session: ["x"], final: ["a", "x"])
        #expect(orphans.isEmpty)
    }

    @Test func everythingDroppedIsDeleted() {
        let orphans = MediaStore.orphanedFiles(original: ["a"], session: ["x", "y"], final: ["a"])
        #expect(orphans == ["x", "y"])
    }
}
