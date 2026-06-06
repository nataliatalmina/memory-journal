# Memory Journal — Project Context

This file gives Claude Code the standing context it needs for every session in this repo. Read it before doing any work.

## What this app is

Memory Journal is a SwiftUI iOS app that encourages reflection by resurfacing past entries written on the same calendar date. On a given day, the user sees today's entry alongside entries from that same date across the previous years (or months). Example: on 15 August 2026 the user sees entries from 15 Aug 2026, 15 Aug 2025, 15 Aug 2024, and so on.

The user chooses during onboarding whether to look back across **5 years** or **5 months**, and can change this later in Settings.

## Developer context — READ THIS

The owner of this project is **new to Swift and SwiftUI**. When you write or change code:

- Explain what you're doing and why, in plain language, as you go.
- When you use a Swift or SwiftUI concept that a beginner may not know (e.g. `@Model`, `@Query`, property wrappers, `some View`, optionals, closures), add a one-line explanation in a comment or in your message.
- Prefer clear, conventional code over clever or terse code.
- When there's a meaningful choice to make, briefly state the options and why you picked one, rather than silently deciding.
- Don't assume familiarity with Xcode workflows — spell out where files go and what to click when it matters.

## Technical baseline

- **Platform:** iOS 26+ only. Use modern SwiftUI APIs freely; do not add back-compatibility shims for older iOS.
- **Language:** Swift, SwiftUI. No UIKit unless a feature genuinely requires it (e.g. certain media pickers) — and if so, wrap it cleanly and explain why.
- **Persistence:** SwiftData, local-only (see Privacy & data below).
- **Architecture:** Keep it simple and idiomatic for SwiftUI. Use plain SwiftUI state (`@State`, `@Observable`, `@Query`) and small view models only where a view's logic is genuinely complex. Do not impose a heavy MVVM layer everywhere — favour the lightest structure that stays readable.
- **No third-party dependencies** unless we discuss and agree on one first. Prefer Apple frameworks.

## Privacy & data — a hard commitment

The onboarding "access your media" screen tells the user, verbatim: *"we won't store any of your media or personal data."* The architecture must honour this. Treat these as rules, not preferences:

- **All journal data stays on-device.** Use SwiftData with a local store. No remote server, no analytics, no third-party SDKs, no network calls that transmit user content.
- **Media (photos, voice notes) is stored on-device**, inside the app's own container. Do not upload it anywhere.
- **Rely on iOS Data Protection** (encryption at rest when the device is locked) — this is on by default; don't disable it.
- If we later add iCloud sync, it must be **opt-in** in Settings and use the user's own private CloudKit container (end-to-end via their iCloud) — never our own backend. Until we explicitly build that, assume local-only.
- The privacy policy text and the in-app copy must always match what the code actually does. If a feature would break the "we don't store your data" promise, flag it before building it.

## Data model (starting point)

A journal entry has at minimum:

- `id` — unique identifier
- `date` — the calendar date the entry belongs to (store normalised to start-of-day so same-date matching is reliable)
- `title` — optional short title (e.g. "Day at the park")
- `body` — the entry text
- `photoFilenames` — references to image files stored in the app container (not blobs in the DB if they're large; discuss approach)
- `voiceNoteFilename` — optional reference to an audio file
- `promptUsed` — optional reference to the prompt that seeded the entry
- `createdAt` / `modifiedAt` — timestamps

The single most important query in this app: **"give me all entries whose month/day matches a target date, going back N years (or N months), most recent first."** Build and test this early with seeded sample data.

### Phase 1 decisions (recorded)

- **Normalisation time zone:** `Entry.date` is normalised to **start-of-day in the user's current *local* calendar/time zone** (`Calendar.current`), deliberately **not UTC** — an entry belongs to the wall-clock date the user lived. Done in `Entry.init` via `calendar.startOfDay(for:)` (DST-safe). Known limitation: if the user changes time zones after writing, the stored instant doesn't re-normalise (acceptable for a personal journal).
- **Leap-day / short-month rule:** unified into a single rule — "if the target day-of-month doesn't exist in a step's month, **clamp to the last day of that month**" (29 Feb → 28 Feb; the 31st → 30th/28th). Encoded in `DateLookup.OutOfRangeDayRule`, default set by `DateLookup.defaultRule` in `Services/DateLookup.swift`. Alternative `.skip` (drop the step) is a one-line change. Covered by unit tests.
- **The query lives in** `Services/DateLookup.swift`: pure date math (`targetDates`) separated from the DB fetch (`matchingEntries`) so the rules are unit-tested without a database.
- **Media fields** are still just filenames/strings (`photoFilenames`, `voiceNoteFilename`) — real capture and on-disk file storage is deferred to a later phase.
- **Testing:** a `MemoryJournalTests` unit-test target exists, using the Swift Testing framework. Run with the shared `MemoryJournal` scheme.

### Phase 2 decisions (recorded)

- **Onboarding gate:** a single `@AppStorage` bool `hasOnboarded` (key in `App/Preferences.swift`) decides onboarding vs. tab bar in `App/RootView.swift`. The flow is a coordinator (`Onboarding/OnboardingContainerView.swift`) that owns the current step; each screen is its own view and calls a closure to advance.
- **View-mode persistence:** the chosen window is `LookbackMode` (`Models/LookbackMode.swift`, raw values `fiveMonths`/`fiveYears`), persisted via `@AppStorage` under key `lookbackMode`. Onboarding screen 2 writes it on Continue; Settings (Phase 6) will edit it; the journal query reads it via `LookbackMode.lookupMode`.
- **Splash behaviour:** AUTO-ADVANCE ONLY (no tap), per owner. Wordmark + tagline fade in line-by-line, then it advances (~3.2s). Timing is cancel-safe (`.task`). Accessibility note: a purely timed splash with no control could rush VoiceOver users — revisit if testers find it fast.
- **Default view-mode:** Five-Month is pre-selected (matches the Figma, which shows it teal/selected). Exactly one card is always selected, so Continue is always enabled.
- **GIF playback:** SwiftUI can't animate GIFs, so `Shared/GIFImage.swift` decodes frames with ImageIO and steps them via `TimelineView` (no UIKit view, no dependency). Frames are downsampled (the source `Loading.gif` is 2048²) and cached. The GIF has alpha, so it sits correctly on the pale background.
- **Permissions:** `Services/MediaPermissions.swift` wraps Camera (`AVCaptureDevice`), Photo Library (`PHPhotoLibrary`, `.readWrite`), Microphone (`AVAudioApplication`, the iOS-17+ API). It ONLY requests/reads authorization — never stores or transmits media (honours the privacy promise). Usage strings live in build settings as `INFOPLIST_KEY_NS*UsageDescription`. Permissions are optional; "Maybe later" and "Continue" both finish. **Each enable button is sage (`appSecondary`) until granted, then turns teal (`appPrimary`); the label never changes** (per Figma `143-160` initial / `198-461` granted). A denied button stays sage and its tap deep-links to Settings (iOS only prompts once).
- **Privacy policy:** `Onboarding/PrivacyPolicyView.swift` is in-app, scrollable, and **clearly marked DRAFT** — replace with reviewed wording before shipping.
- **Resolved design decisions:**
  - *Button labels:* **italic** serif (PP Kyoto MediumItalic) everywhere, per this file (confirmed by owner). `AppButton` and the permission buttons use `.kyotoItalic`.
  - *One teal only:* use `appPrimary` (`#005363`) for the wordmark and chips. The Figma's slightly greener `#005d4f` was a mistake (confirmed) — do not add it.
  - *Dynamic chips:* approved — the period chips are computed from "now" so they stay accurate.
  - *Splash:* the tagline fades in line by line — "Our memories make us human" first, then "Don't let them fade away".
- **Typography — DONE:** PP Kyoto is registered and active. The full family lives in `DesignSystem/Fonts/`; `UIAppFonts` (in the project-root `Info.plist`) registers the two weights the design system uses — PostScript names **`PPKyoto-Medium`** and **`PPKyoto-MediumItalic`**. `.kyoto`/`.kyotoItalic` use `.custom(...)` with those names, and the tab bar uses `PPKyoto-MediumItalic` via `AppAppearance`. (The other weights are bundled and can be exposed by adding them to `UIAppFonts` + a helper.)
- **DEBUG:** the dev tab (`Dev/DateLookupDevView.swift`) shows the chosen mode and a "Replay onboarding" button (resets `hasOnboarded`).

### Phase 3 decisions (recorded)

- **Home (`Features/Journal/JournalView.swift`):** empty vs. populated is data-driven via `@Query` (auto-updates on save) + the Phase 1 `targetDates`. Today's entry shows in the **header** with an **"Edit memory"** button; the look-back list is strictly past years/months.
- **Composer (`ComposerView.swift`):** one screen for create + edit. **Save rule:** non-whitespace **body** required; title optional, both trimmed (`Entry.cleanedInput`, unit-tested). One entry per day (Create when none, Edit when one exists).
- **Detail (`EntryDetailView.swift`):** tapping a past entry opens a **read-only** view (kept separate from the composer). Hierarchy is all PP Kyoto Medium: with a title → date grey 17 / title teal 24 / body grey 16; without a title → date teal 24 / body grey 16. Body is upright Medium (not forced italic) so the entry's own text shows faithfully.
- **Entry titles** on Home rows use **PP Kyoto Bold** (registered) so they stand out from the italic body.
- **Media storage (`Services/MediaStore.swift`):** photos/audio live in the app container (`Application Support/Media/{Photos,Audio}`); the entry stores only **filenames**, never bytes, never off-device. Saves are **orphan-safe** — files committed on Save, cleaned up on cancel (`orphanedFiles`, unit-tested).
- **Photos (Part C):** max **3**, tap-**✕** to remove. Library via **`PhotosPicker`** (needs no permission — most privacy-preserving; the onboarding "Photo Library" toggle is effectively unused for attaching). Camera via a `UIImagePickerController` wrapper (`Shared/CameraPicker.swift`), gated on camera permission with a graceful Settings route; unavailable in the Simulator. Images are downscaled to ≤2048px JPEG.
- **Voice (Part D):** **one** voice note per entry. `Services/VoiceRecorder.swift` records (record → review → keep/discard) to the container; `Services/VoicePlayer.swift` is a single shared player (injected via environment) so only one note plays at a time. **Waveform is hybrid:** the live recording meter is **real** (`AVAudioRecorder` metering → `Shared/LiveWaveformView.swift`); the saved-note waveform is **representative** (`Shared/WaveformView.swift`). **TODO (owner-requested, later):** persist ~40–50 captured levels alongside the note so the saved waveform can be true amplitude without decoding audio.
- **Composer media icons:** 44×44pt tap targets placed adjacent (HIG minimum + Messages-style density).
- **New colour flagged:** a destructive **red** for the recording "discard" (✕) button — the palette has no red; it's the conventional destructive colour. Confirm or tokenise.
- **Still-open visual flags (unchanged):** body-excerpt uses Medium Italic vs the Figma's Regular Italic; the tab bar is the native iOS bar (lowercase) vs the Figma's tall custom bar; the Home book logo reuses the animated GIF (could be a still frame).
- **DEBUG:** sample data seeds **relative to today** (so the look-back is always populated) with photo/voice/plain variety and a generated sample image + audio (playable). Launch args for previewing states: `-hasOnboarded`, `-seedTodayEntry`, `-openComposer`, `-openDetail`, `-clearEntriesOnLaunch`, `-focusBody`, `-voiceRecording`, `-voiceReview`. Dev tab has Reseed / Clear / Replay onboarding.

## Screens

There are four main screens, reached via a bottom tab bar (Journal, Calendar, Prompts, Settings), plus onboarding.

1. **Journal (Home):** Create a new entry; below it, a scrollable list of past entries for the same date across the chosen lookback window. Empty state when there are no entries yet. Entries can contain text, photos, and a voice note (shown as a playable waveform).
2. **Prompts:** A list of journalling prompts the user can tap; a selected prompt is highlighted; "Get started with prompt" begins a new entry seeded with that prompt.
3. **Calendar:** Month grid with prev/next navigation; tapping a date shows that date's entry below the grid, or an empty message if none.
4. **Settings:** Includes changing the lookback window (5 years / 5 months), media permissions, and access to the privacy policy.

**Onboarding flow:** Loading/splash → "keep your cherished memories" (choose Five-Month or Five-Year view) → "access your media" (request camera, photo library, microphone; "Maybe later" and "Continue" options; link to privacy policy) → into the app.

## Visual design system

The Figma designs commit to a calm, editorial, serif-forward aesthetic. Match it precisely — this restraint is the whole point, so do not introduce extra colours, gradients, or system-default styling. Centralise all of this in a single design-tokens file (colors, fonts, spacing) and reference tokens everywhere rather than hard-coding values in views.

**Colour palette:**

- Primary / deep teal: `#005363` — primary buttons, headings, active tab, selected calendar day.
- Secondary / muted sage-teal: `#5D909B` — secondary/disabled-style buttons (e.g. "Enable Photo Library").
- App background: `#ECEFF5` — pale blue-grey, used on almost every screen.
- Card / surface: `#FBFCFD` — calendar card; journal entry card; tab bar; etc.
- Body text: `#525252` — a warm grey; used for all text within the app, including journal entries.
- Define these as named colors in the asset catalog or a `Color` extension; never scatter raw hex in views.

**Typography** — this is the signature of the app:

- The app uses a custom serif, **PP Kyoto**, throughout. I will place the font files in the relevant directory once the project is scaffolded:
  - `PPKyoto-Medium.otf` — the serif used throughout (headings, body, general text).
  - `PPKyoto-MediumItalic.otf` — italic serif for button labels ("Save your memory", "Create your memory", "Get started with prompt", "Continue"), tab bar labels, and anywhere italic is needed.
- Register both fonts: add the `.otf` files to the project, declare them under `UIAppFonts` in Info.plist, and wrap them in a reusable text style / `Font` extension so views reference named styles (e.g. `.kyoto(size:)`, `.kyotoItalic(size:)`) rather than raw font names.
- The exact PostScript names inside the `.otf` files may differ from the filenames — confirm them when registering, and use the real PostScript name in code. **(Confirmed: they match the filenames — `PPKyoto-Medium` and `PPKyoto-MediumItalic`.)**
- ~~Until the files are added, fall back to the closest built-in serif.~~ **DONE (Phase 2):** the full PP Kyoto family is in `DesignSystem/Fonts/`; `PPKyoto-Medium.otf` + `PPKyoto-MediumItalic.otf` are registered via `UIAppFonts` in the project-root `Info.plist` (merged with the auto-generated plist), and `.kyoto`/`.kyotoItalic` now resolve to the real font.

**Components & layout:**

- Generous whitespace; onboarding text is centered.
- Full-width rounded buttons (substantial corner radius, comfortable vertical padding).
- The calendar is a white rounded card floating on the pale background; the selected day is a filled teal circle.
- Line-art icons for the tab bar and the in-entry media controls (camera, photo, microphone).
- Lowercase styling on some titles ("memory journal", "journalling prompts", "access your media") — preserve the exact casing from the designs.

When in doubt about a visual detail, ask to see the relevant Figma screen rather than guessing.

## How we work together

- We build this **one screen / one flow per session.** Don't try to scaffold the whole app at once.
- At the start of a screen session, I'll paste the relevant Figma screenshot and a detailed flow description. Build to that.
- Keep changes scoped to what we're discussing; don't refactor unrelated code without asking.
- After meaningful changes, tell me how to run/see the result in Xcode.
- Update this file when we make a decision worth remembering (e.g. final font names, exact hex values, the media-storage approach).

## Build order (roadmap)

- [x] **Phase 0 — Scaffolding:** Xcode project, folder structure, design tokens (colors, fonts, spacing), this CLAUDE.md, app entry point, empty tab bar with four tabs.
- [x] **Phase 1 — Data + the core query:** SwiftData model, seeded sample data, the "same date across N years/months" query, verified in a throwaway list view.
- [x] **Phase 2 — Onboarding:** splash → view-mode selection → media permissions → privacy policy link.
- [x] **Phase 3 — Journal/Home screen** (empty state, create entry, past-entries list, media in entries).
- [ ] **Phase 4 — Prompts screen.**
- [ ] **Phase 5 — Calendar screen.**
- [ ] **Phase 6 — Settings screen** (incl. changing lookback window, permissions, privacy policy).

Work top to bottom. Don't start a phase before the ones it depends on are done.
