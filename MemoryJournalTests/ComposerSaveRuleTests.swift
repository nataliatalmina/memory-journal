//
//  ComposerSaveRuleTests.swift
//  MemoryJournalTests
//
//  The composer's "enough to save" rule (Phase 3B): body must have real text,
//  title is optional, both are trimmed.
//

import Testing
@testable import MemoryJournal

@MainActor
struct ComposerSaveRuleTests {

    @Test func emptyOrWhitespaceBodyCannotSave() {
        #expect(Entry.cleanedInput(title: "A title", body: "") == nil)
        #expect(Entry.cleanedInput(title: "A title", body: "   \n  \t ") == nil)
    }

    @Test func titleAloneIsNotEnough() {
        // A title with no body still can't be saved.
        #expect(Entry.cleanedInput(title: "Just a title", body: "  ") == nil)
    }

    @Test func bodyTextIsEnough_andEmptyTitleBecomesNil() throws {
        let cleaned = try #require(Entry.cleanedInput(title: "   ", body: "  Hello world  "))
        #expect(cleaned.title == nil)            // blank title → nil
        #expect(cleaned.body == "Hello world")   // trimmed
    }

    @Test func titleAndBodyAreTrimmed() throws {
        let cleaned = try #require(Entry.cleanedInput(title: "  Park  ", body: "\n went out today \n"))
        #expect(cleaned.title == "Park")
        #expect(cleaned.body == "went out today")
    }
}
