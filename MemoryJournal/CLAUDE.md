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
- **Privacy policy:** `Onboarding/PrivacyPolicyView.swift` is in-app and scrollable. The wording is now **finalised** (effective 19 June 2026) and written to match actual behaviour; keep it in sync if data handling ever changes. NOTE: the App Store also needs a **publicly hosted copy at a URL** (e.g. memoryjournalapp.com/privacy) — same text — entered in App Store Connect.
- **Resolved design decisions:**
  - *Button labels:* **italic** serif (PP Kyoto MediumItalic) everywhere, per this file (confirmed by owner). `AppButton` and the permission buttons use `.kyotoItalic`.
  - *One teal only:* use `appPrimary` (`#005363`) for the wordmark and chips. The Figma's slightly greener `#005d4f` was a mistake (confirmed) — do not add it.
  - *Dynamic chips:* approved — the period chips are computed from "now" so they stay accurate.
  - *Splash:* the tagline fades in line by line — "Our memories make us human" first, then "Don't let them fade away".
- **Typography — DONE:** PP Kyoto is registered and active. The full family lives in `DesignSystem/Fonts/`; `UIAppFonts` (in the project-root `Info.plist`) registers the two weights the design system uses — PostScript names **`PPKyoto-Medium`** and **`PPKyoto-MediumItalic`**. `.kyoto`/`.kyotoItalic` use `.custom(...)` with those names. (The custom tab bar's italic labels use `.kyotoItalic` directly — see the post-v1 tab-bar note; the old `AppAppearance` UIKit styling was removed when the native bar was replaced.) (The other weights are bundled and can be exposed by adding them to `UIAppFonts` + a helper.)
- **DEBUG:** the dev tab (`Dev/DateLookupDevView.swift`) shows the chosen mode and a "Replay onboarding" button (resets `hasOnboarded`).

### Phase 3 decisions (recorded)

- **Home (`Features/Journal/JournalView.swift`):** empty vs. populated is data-driven via `@Query` (auto-updates on save) + the Phase 1 `targetDates`. Today's entry shows in the **header** with an **"Edit memory"** button; the look-back list is strictly past years/months.
- **Composer (`ComposerView.swift`):** one screen for create + edit. **Save rule (updated):** an entry needs **any real content** — body text, **a photo, or a voice note** (`Entry.hasSavableContent`); title is optional and never enough alone. `Entry.cleanedInput` now just trims (title blank → nil, body trimmed, may be empty for media-only). Both unit-tested (`ComposerSaveRuleTests`). One entry per day (Create when none, Edit when one exists). **Dismiss = auto-save:** swiping the sheet away **auto-saves** when there's savable content (no Cancel button), so a draft is never silently lost; an in-progress/unconfirmed recording is dropped first, and with nothing savable the dismiss just cleans up.
- **Detail (`EntryDetailView.swift`):** tapping a past entry opens a **read-only** view (kept separate from the composer). Hierarchy is all PP Kyoto Medium: with a title → date grey 17 / title teal 24 / body grey 16; without a title → date teal 24 / body grey 16. Body is upright Medium (not forced italic) so the entry's own text shows faithfully.
- **Entry titles** on Home rows use **PP Kyoto Bold** (registered) so they stand out from the italic body.
- **Media storage (`Services/MediaStore.swift`):** photos/audio live in the app container (`Application Support/Media/{Photos,Audio}`); the entry stores only **filenames**, never bytes, never off-device. Saves are **orphan-safe** — files committed on Save, cleaned up on cancel (`orphanedFiles`, unit-tested).
- **Photos (Part C):** max **3**, tap-**✕** to remove. Library via **`PhotosPicker`** (needs no permission — most privacy-preserving; the onboarding "Photo Library" toggle is effectively unused for attaching). Camera via a `UIImagePickerController` wrapper (`Shared/CameraPicker.swift`), gated on camera permission with a graceful Settings route; unavailable in the Simulator. Images are downscaled to ≤2048px JPEG.
- **Voice (Part D):** **one** voice note per entry. `Services/VoiceRecorder.swift` records (record → review → keep/discard) to the container; `Services/VoicePlayer.swift` is a single shared player (injected via environment) so only one note plays at a time. **Waveform is now REAL end-to-end:** the live meter uses `AVAudioRecorder` metering (`Shared/LiveWaveformView.swift`); the **saved** waveform is true amplitude too — the recorder accumulates the full level history, downsamples it to `VoiceRecorder.savedBarCount` (48) on `confirm()`, and persists it in a **sidecar next to the audio** (`<uuid>.m4a.levels`, JSON `[Float]`) via `MediaStore.saveLevels`. `WaveformView` takes optional real `levels` (loaded by `MediaStore.loadLevels(forAudio:)` in `VoiceNotePlayerBar`) and falls back to a representative pattern only when there's no sidecar. The sidecar shares the audio's lifecycle: `MediaStore.deleteAudio` removes it, `deleteAllMedia` clears the Audio dir, and orphan cleanup keys off the audio filename. Downsampling is pure + unit-tested (`WaveformLevelsTests`). DEBUG seed writes a decaying sample sidecar so seeded notes show a real-looking waveform.
- **Composer media icons:** 44×44pt tap targets placed adjacent (HIG minimum + Messages-style density).
- **Destructive red (confirmed + tokenised):** `Color.appDestructive` (`#CC4D4A`), used for the recording "discard" (✕) button. Owner-approved; now part of the palette.
- **Visual flags — resolved/updated:**
  - *Body excerpt font:* **Medium Italic** vs the Figma's Regular Italic — **owner-confirmed to keep** Medium Italic (no need to register the Regular weight).
  - *Splash/Home wordmark teal:* **owner-confirmed** to keep the single `appPrimary` `#005363` (not the Figma's #005d4f).
  - *Home book logo:* now the **custom static `Home` image** in the asset catalog (`Assets.xcassets/Home.imageset`), used in both Home states via `Image("Home")` — replaced the reused animated GIF. (The splash and the App Lock screen still use the animated `Loading.gif`.)
  - *Tab bar:* **DONE — custom tab bar** (`App/MemoryTabBar.swift`) replaced the native iOS bar. See the post-v1 note below.

### Post-v1 polish — custom tab bar

- **`App/MemoryTabBar.swift` + `App/RootTabView.swift`:** the native `TabView` was replaced with a bespoke bar to match the owner's Figma (`node 260-507`): hand-drawn icons above **italic-serif, Title-Case** labels ("Journal", "Calendar", …) — note this is **Title Case**, a deliberate change from the old lowercase native labels, per the design.
- **Icons:** owner-supplied PNGs, an `_active` (teal) and `_inactive` (grey) per tab, in the asset catalog (`Journal_active.imageset`, etc.). They're **pre-coloured**, so selecting a tab just swaps the image — we don't tint in code. Source art was 2048² and **downscaled to 144²** when imported (a 2048² asset for a ~30pt icon wastes memory/decode). The design's `#005363` / `#525252` are exactly `appPrimary` / `appBodyText`, so labels use those tokens.
- **Container:** not `TabView`. All tab screens are kept alive in a `ZStack` (only the selected one is visible / hit-testable / VoiceOver-visible) so each tab **preserves its state** (scroll, the Calendar's selected day, a pushed Journal detail) — verified in the sim. The bar is attached with `.safeAreaInset(edge: .bottom)` so content insets correctly above it on every device; its `appSurface` background ignores the bottom safe area to reach the screen edge, with a hairline along the top.
- **Sizing adaptation (flagged):** the Figma shows 48pt icon frames; rendered at ~30pt visible (the PNGs carry internal padding) — a deliberate iOS-appropriate adaptation rather than literal 48pt. Labels are `kyotoItalic(14)` with `minimumScaleFactor` so they stay one line under large Dynamic Type.
- **DEBUG:** the dev tab is appended as a 5th item (SF Symbol `ladybug`) in debug builds only; release shows the four designed items.
- **Removed:** `DesignSystem/AppAppearance.swift` (it only styled the native `UITabBar`, now unused).
- **DEBUG:** sample data seeds **relative to today** (so the look-back is always populated) with photo/voice/plain variety and a generated sample image + audio (playable). Launch args for previewing states: `-hasOnboarded`, `-seedTodayEntry`, `-openComposer`, `-openDetail`, `-clearEntriesOnLaunch`, `-focusBody`, `-voiceRecording`, `-voiceReview`. Dev tab has Reseed / Clear / Replay onboarding.

### Phase 4 decisions (recorded)

- **Prompts screen (`Features/Prompts/PromptsView.swift`):** title, intro, five date-seeded cards, and a "Get started with prompt" button that appears (animated) only when a card is selected.
- **Master list (`PromptLibrary.all`):** an in-code static `[String]` (~55 starter prompts) — NOT SwiftData. Prompts are static, read-only, identical for all users, so they belong in code (or a bundled JSON later), not the user's store. Replace/extend the starter wording freely.
- **Daily rotation (`DailyPrompts.selection`):** derive a `dayNumber` from the **local** calendar day (start-of-day; flips at local midnight, same basis as `Entry.date`), seed a SplitMix64 `SeededGenerator`, shuffle the indices, take 5. Stable all day, fresh next day, 5 distinct (no within-day repeats), and the mixer avalanches so consecutive days don't form an obvious cycle. Guards a short/empty list (`min(count, list.count)`). Pure + unit-tested.
- **Selection:** single. Tapping the selected card again **deselects** it (toggle). Cards are real selectable buttons (NOT disabled controls) — unselected uses the pale-teal treatment below; selected is solid teal + white. VoiceOver gets `.isSelected`.
- **Composer reuse:** `ComposerView` gained a `prompt:` parameter — it seeds the **title** (only if the title is empty, so editing never clobbers) and records `promptUsed`. The title field is now **multi-line** so long prompt-titles wrap (also better for long manual titles).
- **Today-only / one entry per day:** a prompt always targets **today** (`date = real today`, never a past date). If today's entry **already exists**, the Prompts screen does NOT offer a second prompt — it shows an "already written today / one a day, fresh prompts tomorrow" message + a **"View today's memory"** button (→ Home). New entries only when there's none yet.
- **After saving a prompted entry → jump to Home** so the new memory is visible. Done via `ComposerView`'s `onSaved` callback + the sheet's `onDismiss` (only on a real save, not a swipe-cancel), which sets `AppRouter.selectedTab = .journal`.
- **Card style + contrast (resolved):** unselected prompt cards use a pale teal fill (`appPrimary` @10%) + **teal text** — high-contrast AND clearly distinct from the solid-teal selected/CTA. (We tried darkening `appSecondary` to `#4A737C` for contrast, but it read too close to the primary teal, so `appSecondary` stays the original `#5D909B` and the cards use this treatment instead.) Selected card stays solid teal + white.
- **Tab navigation:** `App/AppRouter.swift` (`@Observable`, injected in the environment) owns the selected `AppTab`; `RootTabView` binds the `TabView` to it. Enables cross-tab navigation (and the DEBUG `-startTab`).
- **Title position:** the "journalling prompts" title (and the block under it) sits `Spacing.xxxl` (64pt, new step in the scale) below the safe area — ≈ the Figma's Y≈127, but as a fixed offset from the status bar so it adapts across device sizes rather than a hard-coded Y.
- **Open accessibility flag:** onboarding's sage "Enable" buttons (white on `#5D909B`) are ≈3.5:1 contrast, below WCAG AA — kept as the original design (we reverted the darker sage because it read too close to the primary teal). Revisit separately if wanted.
- **DEBUG:** on-screen day simulator (−1 / Today / +1) on the Prompts screen to verify rotation without waiting; launch args `-startTab <journal|calendar|prompts|settings|dev>`, `-selectFirstPrompt`, `-openPromptComposer`.

### Phase 5 decisions (recorded)

- **Calendar (`Features/Calendar/CalendarView.swift`):** pure single-date look-up and **read-only**. It never opens the composer, creates, or edits. Tapping a day with an entry renders it via **`EntryReadContent`** — extracted from `EntryDetailView` so the entry presentation is **identical** to Home's detail view and exposes no editing controls.
- **Grid maths (`Features/Calendar/CalendarMonth.swift`):** pure, no SwiftUI/DB (mirrors how `DateLookup` isolates date math); unit-tested in `CalendarMonthTests`. Leading blanks = `(weekdayOfFirst − firstWeekday + 7) % 7`; the weekday header is `calendar.shortWeekdaySymbols` rotated by `firstWeekday` — **derived from `Calendar`, never hardcoded**. This fixes the mockup's garbled "SUN MON WED … SUN" header and adapts to locale (verified Monday-first in the sim).
- **Time zone:** the grid and selection use `Calendar.current` (local), the **same** basis as `Entry.date`'s Phase 1 start-of-day normalisation, so a tapped grid day compares exactly to a stored entry's date.
- **Forward navigation — CAPPED at the current month** (owner-decided): the next chevron is disabled + dimmed once you reach this month (future dates can't have entries); backward is unlimited. Changing month clears the selection.
- **Default selection — NONE** (owner-decided, matches the mockup): on open nothing is selected, today is plain text (no special "today" marker), and a gentle hint ("Select a date to see your memory for that day.") sits below the card until a day is tapped. A selected day is a filled teal circle (`appPrimary` `#005363`) + white text. (The hint is a small addition beyond the blank mockup.)
- **Entry dots — ADDED** (owner-approved): a small teal dot under days that have an entry; hidden when that day is selected (the fill is the indicator) and always laid out at opacity 0 so rows don't shift. Live via `@Query`.
- **One entry per date:** the model only makes `id` unique, **not** `date` — multiple-per-date is technically possible in the store, but the Phase 3 composer flow guarantees one per day and there's no other create path, so Calendar queries the single entry (newest-first, defensively). No multi-entry list UI was built (the case can't occur via the app).
- **Tokens added:** `CornerRadius.largeCard` (20 — the floating calendar card) and `Date.monthYearHeading()` ("August 2026", title-case, unlike the lowercase `journalHeading()`).
- **Deviations from the calendar mockup (owner-confirmed):** reusing the Phase 3 entry view means (a) the date heading stays **grey when the entry has a title** (the calendar mockup showed it teal), and (b) photos render **full-width stacked** (the mockup showed a 3-thumbnail row). Owner **confirmed** keeping both as Phase 3 for cross-screen consistency with Home (rather than matching the calendar-specific mockup). Also: the Figma calendar is Apple's **stock graphical date-picker** in a card — we built a custom grid instead (per the brief) for the serif type, exact teal, entry dots, and read-only selection.
- **Accessibility:** each day cell is a button with `accessibilityLabel` = full date, value = "Has an entry"/"No entry", `.isSelected` trait; the weekday header is hidden from VoiceOver (cells already announce dates); chevrons are labelled "Previous/Next month"; day numbers use `minimumScaleFactor` for large Dynamic Type.
- **DEBUG:** launch args `-startTab calendar` (existing), `-calendarSelectEntry` (jump to the newest entry's month and select it), `-calendarSelectToday` (select today → shows the empty-date state with the default seed).

### Phase 6 decisions (recorded)

- **Settings (`Features/Settings/SettingsView.swift`):** custom grouped cards in the app's editorial style (off-white rounded groups, PP Kyoto, lowercase section titles) — **not** stock `Form` — so it matches the rest of the app. Sections: **look-back · permissions · privacy & security · data · about**.
- **Look-back — same source of truth:** binds to the SAME `@AppStorage(PreferenceKey.lookbackMode)` that onboarding writes and `JournalView` reads — NOT a copy. A two-segment control (Five-Month / Five-Year) + example chips mirroring onboarding. **Verified live in the sim both directions** (changing it here immediately changes Home's look-back list).
- **Permissions:** rows show **real** status via `MediaPermissions.status(of:)`; not-determined → in-app system prompt; granted/denied → deep-link to the app's page in the Settings app (`UIApplication.openSettingsURLString`). Honest wording (On / Off / Enable). (iOS only prompts once, so already-decided permissions must be changed in Settings — same pattern as onboarding.)
- **Privacy policy:** reuses the onboarding `PrivacyPolicyView` (one copy, now **finalised**) via a sheet.
- **App Lock — BUILT FULLY (owner-approved).** `Services/BiometricLock.swift` wraps `LocalAuthentication` using `.deviceOwnerAuthentication` (biometrics **with automatic passcode fallback**). `App/AppLock.swift` (`@Observable`, env-injected) owns `isLocked`: locks on cold launch if enabled and when the app backgrounds (`.inactive`/`.background`), guarded by `isAuthenticating` so presenting Face ID doesn't self-relock. `App/LockScreenView.swift` covers the app (doubles as the app-switcher privacy cover) with an Unlock button; `RootView` auto-prompts on cold launch (`.task`) and on foreground (`scenePhase` `onChange`). The toggle is **disabled with guidance** when no biometrics/passcode are enrolled, and its subtitle adapts (Face ID / Touch ID / passcode). New key `PreferenceKey.appLockEnabled` (default **false**); added `INFOPLIST_KEY_NSFaceIDUsageDescription` to both build configs. **Decision:** the toggle enables/disables the setting **directly** (no confirm-auth-on-enable) — `deviceOwnerAuthentication` always offers the passcode, so there's no lock-out risk, and a detached `Task` inside a custom `Binding` setter was fragile. Verified end-to-end in the sim: lock on launch/background, unlock with a matching face, stays locked on a non-matching face.
- **Delete all data — BUILT (owner-approved).** A destructive row → standard destructive confirmation alert ("This cannot be undone."); on confirm it deletes all `Entry` records and removes all media via the new `MediaStore.deleteAllMedia()` (deletes the Photos/Audio dirs, recreates them empty).
- **About:** app name, version/build read from the bundle (`CFBundleShortVersionString`/`CFBundleVersion`), the splash tagline, and an honest "Local-only. Your memories stay on this device." line (honesty rule).
- **"Future" items LEFT OUT (owner decision):** iCloud sync, Export/backup, and Daily reminder are **not** shown at all (no "coming soon" rows). Nothing is wired (no CloudKit, no notifications), so there's no false privacy implication. Revisit when actually building them.
- **Accessibility:** permission rows expose name + status + a "Asks for permission"/"Opens Settings" hint; the App Lock row combines children with a descriptive hint; the toggle uses the teal tint; the destructive row has a "cannot be undone" hint.
- **Open flag (minor):** `BiometricLock.availability()` is read in `.onAppear`, so enrolling Face ID *while staring at* Settings won't refresh the subtitle until you leave and return (normal tab switching re-runs it). Acceptable; revisit if needed.
- **Roadmap complete:** Phase 6 was the final phase — all six phases are done.

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
- Secondary / muted sage-teal: `#5D909B` — secondary surfaces (onboarding "Enable" buttons, unselected view-mode card). (NB: the **prompt cards** do NOT use this — see Phase 4 decisions; they use a pale-teal-fill + teal-text treatment for contrast.)
- App background: `#ECEFF5` — pale blue-grey, used on almost every screen.
- Card / surface: `#FBFCFD` — calendar card; journal entry card; tab bar; etc.
- Body text: `#525252` — a warm grey; used for all text within the app, including journal entries.
- Destructive / muted red: `#CC4D4A` — destructive actions only (e.g. discard a recording). Added Phase 3 (the editorial palette has no red); kept muted to fit. Token: `Color.appDestructive`.
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
- [x] **Phase 4 — Prompts screen.**
- [x] **Phase 5 — Calendar screen.**
- [x] **Phase 6 — Settings screen** (lookback window, permissions, privacy policy, App Lock, delete all data, about).

Work top to bottom. Don't start a phase before the ones it depends on are done.
