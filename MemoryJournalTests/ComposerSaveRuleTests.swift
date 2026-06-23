//
//  ComposerSaveRuleTests.swift
//  MemoryJournalTests
//
//  The composer's save rule: an entry needs ANY real content — body text, a
//  photo, or a voice note (`hasSavableContent`); a title alone is not enough.
//  `cleanedInput` just trims the text (title blank → nil, body trimmed).
//

import Testing
@testable import MemoryJournal

@MainActor
struct ComposerSaveRuleTests {

    // MARK: - hasSavableContent (the gate)

    @Test func bodyTextIsSavable() {
        #expect(Entry.hasSavableContent(body: "Today was good", photoCount: 0, hasAudio: false))
    }

    @Test func emptyOrWhitespaceWithNoMediaIsNotSavable() {
        #expect(!Entry.hasSavableContent(body: "", photoCount: 0, hasAudio: false))
        #expect(!Entry.hasSavableContent(body: "   \n\t ", photoCount: 0, hasAudio: false))
    }

    @Test func aPhotoAloneIsSavable() {
        #expect(Entry.hasSavableContent(body: "", photoCount: 1, hasAudio: false))
    }

    @Test func aVoiceNoteAloneIsSavable() {
        #expect(Entry.hasSavableContent(body: "  ", photoCount: 0, hasAudio: true))
    }

    @Test func titleAloneIsNotEnough() {
        // The title isn't even an input to the gate — only real content counts.
        #expect(!Entry.hasSavableContent(body: "", photoCount: 0, hasAudio: false))
    }

    // MARK: - cleanedInput (trimming only)

    @Test func blankTitleBecomesNil_andBodyIsTrimmed() {
        let cleaned = Entry.cleanedInput(title: "   ", body: "  Hello world  ")
        #expect(cleaned.title == nil)
        #expect(cleaned.body == "Hello world")
    }

    @Test func titleAndBodyAreTrimmed() {
        let cleaned = Entry.cleanedInput(title: "  Park  ", body: "\n went out today \n")
        #expect(cleaned.title == "Park")
        #expect(cleaned.body == "went out today")
    }

    @Test func mediaOnlyEntryKeepsAnEmptyBody() {
        // No body text (carried by media) → trims to an empty string, not a crash.
        let cleaned = Entry.cleanedInput(title: "", body: "   ")
        #expect(cleaned.title == nil)
        #expect(cleaned.body == "")
    }
}
