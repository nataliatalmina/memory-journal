//
//  PromptLibrary.swift
//  MemoryJournal
//
//  The master list of journalling prompts.
//
//  WHERE THIS LIVES (decision): prompts are STATIC app content — read-only, the
//  same for every user, not personal data. So they belong in code (or a bundled
//  resource), NOT in SwiftData (which is for the user's own entries). A plain
//  Swift array is the simplest, type-safe option: no file parsing, version-
//  controlled, easy to edit. If we later want to edit prompts without shipping a
//  build, we can move this to a bundled JSON — same shape.
//
//  STARTER LIST: review/replace these with the finalised wording. The daily
//  screen shows a deterministic 5 of these per day (see DailyPrompts).
//

enum PromptLibrary {
    static let all: [String] = [
        "When do you feel most like yourself?",
        "Describe a memory from your childhood.",
        "If you were free from any obligations, what would you be doing right now?",
        "What small thing has improved your mood lately?",
        "What has been giving you energy lately? What do you find draining?",
        "What are you grateful for today?",
        "Who has shaped who you are, and how?",
        "What does a perfect ordinary day look like for you?",
        "What are you looking forward to?",
        "What's something you changed your mind about recently?",
        "Describe a place where you feel at peace.",
        "What did you need to hear today?",
        "What's a small win from this week?",
        "What are you holding onto that you could let go of?",
        "When did you last feel proud of yourself?",
        "What does rest look like for you right now?",
        "Who would you like to reconnect with, and why?",
        "What's a fear you'd like to face?",
        "What made you laugh recently?",
        "What does home mean to you?",
        "What habit would you like to build?",
        "Describe a meal that brings back memories.",
        "What's something you're curious about lately?",
        "How have you grown in the last year?",
        "What would you tell your younger self?",
        "What does success mean to you now?",
        "Where do you feel most creative?",
        "What's a kindness someone showed you?",
        "What's weighing on your mind today?",
        "What season of life do you feel you're in?",
        "What would you do with an unexpected free afternoon?",
        "What are you learning about yourself?",
        "Describe someone you admire, and why.",
        "What's a boundary you're glad you set?",
        "What does your ideal morning feel like?",
        "What's something beautiful you noticed today?",
        "What are you proud of that no one knows about?",
        "What would make tomorrow feel good?",
        "What's a comfort you return to again and again?",
        "When did you last feel truly present?",
        "What's a question you're sitting with right now?",
        "What would you like to forgive yourself for?",
        "What's a tradition you cherish?",
        "What's changed about your daily routine lately?",
        "Who makes you feel understood?",
        "What's a risk that paid off?",
        "What do you wish you had more time for?",
        "Describe a moment of unexpected joy.",
        "What's something you're working toward?",
        "What does taking care of yourself look like today?",
        "What's a story your family tells about you?",
        "What do you want to remember about this time in your life?",
        "What's something you're ready to begin?",
        "What's been on your heart lately?",
    ]
}
