# Photo look-back — implementation plan (Phase 7)

**Status:** Phases 1–4 built (31 August 2026). Phase 5 (docs, policy, review prep) not started.
**Written:** 31 August 2026.

---

## The problem this solves

keepsake's value comes from the look-back window, but a new user has nothing to look back on. Someone who installs the app today sees an empty Home screen for months (five-month mode) or years (five-year mode) before the feature that makes the app worth keeping starts working.

## The feature

An **opt-in** setting that lets keepsake fill the empty look-back slots with a photo from the user's own library, taken on the same date in the past.

The existing query already asks "did the user write an entry on this date, N steps back?". When the answer is no, and the user has opted in, we show a photo taken on that date instead — in the same place, in the same list, in the same visual rhythm as an entry row.

**Worked example.** Today is 31 Aug 2026 and the user is in five-year mode. They wrote an entry on 31 Aug 2024, but not in 2025, 2023, 2022, or 2021. Home shows:

| Slot | What renders |
| --- | --- |
| 31 Aug 2026 (today) | The existing "Create your memory" prompt, or today's entry. **Unchanged — never a photo.** |
| 31 Aug 2025 | A photo taken that day |
| 31 Aug 2024 | The existing entry |
| 31 Aug 2023 | A photo taken that day |
| 31 Aug 2022 | A photo taken that day |
| 31 Aug 2021 | A photo taken that day |

Any slot with neither an entry nor an available photo renders nothing at all.

---

## Decisions already made

| Question | Decision |
| --- | --- |
| Where does the user opt in? | A toggle on the **existing** look-back selection screen in onboarding (`ViewModeSelectionView`), plus a toggle in Settings. No new onboarding screen. |
| What triggers the iOS permission prompt? | A **tap on an in-context card** in a gap slot on the Journal screen. Never onboarding, never automatically on screen appearance. |
| Does today's slot get a photo? | **No.** Today is unchanged: today's entry, or the "Create your memory" prompt. |
| What does tapping a photo do? | Opens a full-screen viewer. |
| Can the user dismiss a photo? | **Yes, in v1.** Dismissed photos never appear again, and the list is resettable in Settings. |
| How is the photo chosen? | Photos only (no videos, no screenshots), favourites preferred, then a deterministic pick so it stays stable across re-renders. |

---

## Two risks that shape the design

### 1. App Review — guideline 5.1.1(iv)

Build 1.0 (3) was rejected under this guideline (see `MemoryJournal/CLAUDE.md` → "Permission requests"). Two things about this feature collide with that history:

**a) Photo-library permission comes back.** `PhotosPicker` cannot do this — it runs out-of-process and only returns what the user tapped, so it cannot search a library by capture date. This needs `NSPhotoLibraryUsageDescription` and a real `PHPhotoLibrary` request. There is no read-only access level in the Photos framework: you request `.readWrite` and never write.

This is defensible in a way the last request was not. The previous rejection was partly because the app requested access it *never used*. This time the access is the feature.

**b) The onboarding toggle sits near a permission prompt.** The standing rule in CLAUDE.md is "never build a pre-permission priming screen." The design keeps the two apart deliberately:

- The onboarding toggle **stores intent only**. It calls no Photos API and contains no permission vocabulary — no "Allow", "Enable", "Grant", "Access". It is a preference, in the same sense as five-months-vs-five-years, on a screen that is already nothing but preferences.
- The system prompt is triggered later, **by the user tapping a card in the exact place the photo would appear**, on the Journal screen. That is request-in-context at the point of use, which is what the rejection letter asked for.

**Residual risk, stated plainly:** a reviewer on a fresh install still sees the toggle and then, a screen later, the prompt. This is the strongest available position but not a guarantee. **Build the onboarding toggle so it can be deleted in a single-screen change** — if rejected, the fix is to drop it from `ViewModeSelectionView` and keep the Settings toggle plus the in-context card, which is a fully functional version of the feature.

### 2. The date trap

`Entry.date` is UTC midnight (see CLAUDE.md → "Entry date encoding"). `PHAsset.creationDate` is a plain instant with no time zone attached. **These are different encodings of "a day" and converting between them wrong is the same class of bug as the Santorini one.**

Do **not** feed `Calendar.journal` (UTC) bounds into the Photos query. Asking Photos for `[31 Aug 2025 00:00 UTC, 1 Sep 2025 00:00 UTC)` while the user is in Los Angeles returns photos from 5pm on 30 August to 5pm on 31 August: a photo taken at 8pm on the 31st is missed, and one from the evening of the 30th is wrongly offered as a memory of the 31st.

The correct sequence:

1. Take the canonical target day from `DateLookup.targetDates` (UTC midnight).
2. **Decode** it to year/month/day with `Calendar.journal`.
3. **Rebuild** `[startOfDay, startOfNextDay)` in `Calendar.current`.
4. Use those local bounds in the `PHFetchOptions` predicate.

This is `journalDay(in:)` run backwards. It gets its own documented function in `JournalDay.swift` and its own cross-zone tests.

**Accepted limitation, to be recorded in CLAUDE.md:** photos are matched against the user's *current* time zone, not the capture zone. A photo taken at 00:30 in Tokyo reads as the previous day once the user is back in London, and the Photos app will disagree with keepsake about which day it belongs to. Reading true capture-local time means pulling EXIF `DateTimeOriginal` for every candidate asset, which is far too expensive for a screen that renders on every app open. Match on the current local calendar and move on.

**Free win:** because the photo lookup consumes `DateLookup.targetDates`, it inherits the leap-day / short-month clamping (29 Feb → 28 Feb, 31st → 30th) automatically. Never recompute the target dates.

---

## Phase 1 — Date math and preferences ✅ BUILT

No Photos framework, no UI. Fully unit-testable, ships behind nothing because nothing reads it yet.

*Built as planned, with two deliberate changes: the bounds are returned as a `Range<Date>` rather than a tuple, and the dismissal store got its own test file.*

### `MemoryJournal/Shared/JournalDay.swift`

Add the inverse of `journalDay(in:)`:

```swift
func localDayBounds(in local: Calendar = .current) -> Range<Date>?
```

**Returns a half-open `Range`, not a `(start, end)` tuple.** `start..<end` states the half-openness in the type, and `contains(_:)` then gets the boundary right for free — a midnight photo can't be double-counted into two days. Anchored on **noon**, not midnight, because some days have no midnight: where clocks jump forward at 00:00 the day begins at 01:00, and asking for an instant that doesn't exist gets you a silently adjusted answer.

Decodes a canonical UTC-midnight journal day back to year/month/day using `Calendar.journal`, then rebuilds `[startOfDay, startOfNextDay)` in `local`.

This belongs in this file rather than in the new service, because it is a rule about the entry-date encoding and needs to sit under the doc comment that explains why that encoding exists. Extend that header comment with a paragraph: *entry dates are UTC-encoded, but anything matched against the outside world — photo capture times, calendars, files — must be converted back to local bounds first.*

### `MemoryJournal/App/Preferences.swift`

Two new keys, with doc comments in the existing style:

- `photoLookbackEnabled` — `Bool`, default `false`. The user's **intent**, stored independently of the OS permission. Both can be true; either can be false.
- `dismissedPhotoIdentifiers` — an array of `PHAsset.localIdentifier` strings.

`@AppStorage` does not handle arrays. Add a small `PhotoDismissals` helper enum wrapping `UserDefaults.standard` (`all`, `add(_:)`, `clear()`, `count`) rather than fighting the property wrapper.

### `MemoryJournalTests/PhotoDayBoundsTests.swift` (new)

Follows the cross-zone discipline established in `DateLookupTests` — **write in one zone, read in another**, which is the discipline the original date tests lacked:

- A journal day built in London, read with an `America/Los_Angeles` calendar, produces bounds containing 8pm local on that date and excluding 5pm the previous day.
- Half-open bounds: 23:59:59 on the day is inside, exact midnight the next day is outside.
- 29 Feb and 31st-of-month targets (fed from `DateLookup.targetDates`) produce bounds on the **clamped** day.
- DST transition days: the day is 23 or 25 hours long and the bounds must cover it exactly.

Built with two additions: a test that constructs the **wrong** version (canonical instant + 24 hours) and asserts it both misses the real photo and matches the wrong one, so the failure mode is visible in the suite rather than only in this document; and a São Paulo case for the missing-midnight day.

### `MemoryJournalTests/PhotoDismissalsTests.swift` (new)

Not in the original plan. The dismissal store has real behaviour worth pinning — dedupe, persistence, clearing — and a dismissal that silently fails to stick means re-offering a photo someone asked to be rid of. Each test uses its own throwaway `UserDefaults` suite.

---

## Phase 2 — The lookup service and the permission ✅ BUILT

*Built as planned. Three notes on what the compiler and the intermediate state forced:*

- **`ComposerView` needed the `.limited` case too**, not just `SettingsView` — its camera and microphone switches are exhaustive over `PermissionStatus`. Neither API can return `.limited`, so both handle it alongside `.denied` with a comment saying why it's unreachable.
- **The Settings permission-row filter moved forward from Phase 4.** Adding the `photoLibrary` case makes a Photos row appear in Settings immediately, and a permission row for a feature that doesn't exist yet is the exact shape of the thing that got build 1.0 (3) rejected. Filtering on `photoLookbackEnabled` now means no intermediate state ever shows it.
- **`Calendar.journal` and `localDayBounds(in:)` are now `nonisolated`.** The project defaults to main-actor isolation, and the photo fetch runs on a background task; without this it's a warning today and an error under the Swift 6 language mode.

### `MemoryJournal/Services/MediaPermissions.swift`

Add `photoLibrary` to `MediaCapability`, backed by `PHPhotoLibrary.authorizationStatus(for: .readWrite)` and `PHPhotoLibrary.requestAuthorization(for: .readWrite)`. Comment the `.readWrite`-but-never-write point explicitly, given this file's history.

`PermissionStatus` needs a fourth case: **`.limited`**.

This is the important one. "Selected Photos" makes the feature look silently broken — the app can only see the handful of assets the user picked, so nearly every slot comes up empty and looks identical to "no photos found". It must be detected and explained, never rendered as silence.

Adding the case forces handling in the `switch` statements in `SettingsView`'s `PermissionRow` (`valueText`, `valueColor`, `act`). The compiler will point at each one.

Rewrite the file header comment — it currently states that there is deliberately no photo-library capability, which stops being true.

### `MemoryJournal/Services/PhotoLookback.swift` (new)

Mirrors the split that has worked well in `DateLookup`: pure, testable date/selection logic separated from the framework call.

**Pure half** (no `Photos` import, unit-testable):

```swift
struct PhotoCandidate {
    let localIdentifier: String
    let creationDate: Date
    let isFavorite: Bool
    let isScreenshot: Bool
}

func select(from candidates: [PhotoCandidate],
            seed: Date,
            blocked: Set<String>) -> PhotoCandidate?
```

Drops screenshots and blocked identifiers, prefers favourites when any survive, sorts by identifier, then picks deterministically from what remains.

**The sort matters.** Without it the pick depends on the order Photos happened to return assets in, which is not ours to rely on — the same day could yield a different photo after a library change that didn't touch that day at all.

**The pick must be stable.** `randomElement()` is wrong here: `JournalView` re-renders on every `@Query` change and every sheet presentation, so a fresh random pick would visibly swap the photo under the user. Seed from the target date. Note that `Date.hashValue` is **not** stable across process launches — use something like `Int(seed.timeIntervalSince1970) % count`.

**Photos half:**

```swift
func photos(for targetDates: [Date]) async -> [Date: PhotoCandidate]
```

- Builds local bounds per target date via Phase 1.
- ORs them into a single `NSCompoundPredicate` (with `mediaType == .image`) for **one** `PHAsset.fetchAssets` call, not five.
- Maps assets to `PhotoCandidate`, groups by which range each fell into, runs `select` per date.
- Screenshot and favourite filtering happen **in Swift after the fetch**, not in the predicate — Photos is fussy about which keys its predicates accept, and the candidate set is small.

### `MemoryJournal.xcodeproj/project.pbxproj`

Add `INFOPLIST_KEY_NSPhotoLibraryUsageDescription` to **both** the Debug and Release configs (near the existing camera/mic keys, ~lines 377 and 419), in the same tone:

> keepsake looks for a photo taken on this date in a past year, to show where you didn't write an entry. Photos are displayed from your library and never copied, stored, or uploaded.

### `MemoryJournalTests/PhotoLookbackTests.swift` (new)

- Screenshots excluded.
- Blocked identifiers excluded.
- A favourite wins over a non-favourite.
- The same seed gives the same pick twice (stability).
- Different target dates give different picks.
- An empty or fully-filtered candidate list returns `nil`.

The Photos fetch itself is not unit-testable without a library — which is exactly why the date and selection logic lives behind a `PHAsset`-free boundary.

---

## Phase 3 — The Journal screen ✅ BUILT

*Built as planned, with four changes made while looking at it on a device:*

- **The offer card appears in the topmost gap only**, not in every empty slot. Repeated down a sparse week it stopped reading as a quiet offer and started reading as nagging.
- **`.limited` gets its own row** (`LookbackPhotoLimitedRow`) in that same single slot, rather than being folded into the offer card. It is a different message — not "shall I?" but "I can only see part of your library".
- **The viewer is a `fullScreenCover`, not a `.sheet`.** The plan's reason for avoiding a push still holds; full screen simply gives the photo the whole display, which is the point of opening it.
- **The empty state's third variant is an extra line, not a replacement.** The two existing headline/invitation pairs stay exactly as they were; a muted note appears under them when photo look-back is on and genuinely found nothing, or when limited access is why. Replacing the copy would have meant three near-identical variants to keep honest.

### `MemoryJournal/Features/Journal/JournalView.swift`

The real surgery. `lookbackEntries` — currently a flat filtered array — becomes an ordered slot list built from `targetDates`, **skipping index 0** (today is unchanged):

```swift
enum LookbackSlot: Identifiable {
    case entry(Entry)
    case photo(date: Date, candidate: PhotoCandidate)
    case offer(date: Date)   // the enable card, shown only until access is granted
}
```

- Photos load in a `.task` keyed on the target dates and mode, into `@State private var photos: [Date: PhotoCandidate]`. It runs only when `photoLookbackEnabled` **and** permission is `.granted`.
- **`isEmpty` must account for photos and offer cards**, or a screen full of photos still renders `EmptyHomeView`.
- **`EmptyHomeView.message` needs a third variant** for "opted in, has permission, genuinely nothing found" — otherwise a user with photos on some dates and none on others gets copy that contradicts what they can see. The existing two variants exist for exactly this honesty reason.

### `MemoryJournal/Features/Journal/LookbackPhotoRow.swift` (new)

The row: teal date heading identical to `EntryRow`'s (`date.journalHeading()` — the formatter is already `.gmt`-pinned; keep it that way), the image, a dismiss affordance, and a tap that opens the viewer. Match `EntryRow`'s padding and `RowDivider` rhythm so photo and entry rows read as one continuous list.

**Dismiss:** prefer a context menu ("Don't show this photo") over a persistent ✕ — a visible close button on a memory photo is visually noisy and easy to hit by accident. On dismiss, add the identifier to `PhotoDismissals` and immediately re-select from the remaining candidates for that date.

### `MemoryJournal/Features/Journal/PhotoLibraryImage.swift` (new)

The async loader view, modelled directly on `PhotoThumbnail` in `EntryRow.swift`: three states (loading / loaded / unavailable), decode off the main thread, fixed frame so there is no layout shift.

Wraps `PHImageManager.requestImage` at display size with `isNetworkAccessAllowed = true` — iCloud-only originals otherwise return a degraded placeholder or nothing. Comment the privacy reasoning: this is Apple fetching the user's own photo from their own iCloud, not keepsake making a network call, so it does not touch the privacy promise.

### `MemoryJournal/Features/Journal/PhotoViewerView.swift` (new)

Full-screen viewer on tap, presented as a **`fullScreenCover`, not pushed**, for the reason already documented at `JournalView.swift:36`: the custom bottom tab bar (added via `.safeAreaInset` in `RootTabView`) overlaps pushed content and traps controls near the bottom. Shows the full-size image, the date, a Done button, and the dismiss action.

The toolbar uses explicit `.topBarLeading` / `.topBarTrailing` placements. The semantic `.destructiveAction` and `.confirmationAction` both resolve to the trailing edge on iOS, which put the two buttons side by side and made "Done" read as a label for the one beside it.

### The offer card

Rendered in a gap slot when `photoLookbackEnabled` is true but permission is not yet granted:

- **`.notDetermined`** — one line ("no entry from 31 august 2025 — show a photo from that day?") and a tap that calls `MediaPermissions.request(.photoLibrary)`. **This tap is the only thing in the app that triggers the Photos prompt.** Once granted, the card never appears again.
- **`.limited`** — a single honest line ("keepsake can only see the photos you selected") linking to Settings.
- **`.denied`** — render nothing at all. Never nag.

---

## Phase 4 — Onboarding and Settings ✅ BUILT

*Built as planned. Two notes:*

- **The onboarding opt-in is an off-white card, not a filled teal one** like the two look-back options above it. It is a secondary choice, and something that looks like a call to action sitting in front of a later permission prompt is the thing we must not build.
- **The "Forget Hidden Photos" row appears only when the count is above zero**, so the setting doesn't advertise a feature the user hasn't met. It needs no confirmation — it restores rather than removes.

### `MemoryJournal/Onboarding/ViewModeSelectionView.swift`

Below the two `LookbackOptionCard`s, above the pinned Continue button:

> **photos from this date**
> When there's no entry from a year ago, keepsake can show a photo you took that day. Nothing is copied or stored.

with a toggle bound to local `@State`, committed in the same `Continue` action that already writes `savedMode`.

Keep it visually and verbally a **preference**, not a call to action. **No "Allow", "Enable", "Turn on", "Grant", or "Access" anywhere on this screen.**

Add a file-header comment explaining that this screen deliberately touches no Photos API and stores intent only — so that nobody later "helpfully" moves the prompt here and reintroduces the 5.1.1(iv) violation.

### `MemoryJournal/Features/Settings/SettingsView.swift`

Four changes:

1. **`lookBackSection`** — the same toggle, under the existing `LookbackSegmented` and chips. It is the same decision domain: what appears in your look-back.
2. **`permissionsSection`** — a Photos row appears automatically via `MediaCapability.allCases`, but it should be **filtered out when the feature is off**. Showing a permission row for a disabled feature is noise. *(Done in Phase 2, ahead of schedule — see that section.)*
3. **"Forget dismissed photos"** row, with a count, so dismissals are not a one-way door.
4. **`deleteAllData()`** must clear the dismissal list too. It is user data, and "Delete All Data" has to mean it.

---

## Phase 5 — Documentation, copy, and review prep

Not deferrable past submission.

### `MemoryJournal/Onboarding/PrivacyPolicyView.swift`

The bullet "Photo library — to add a photo you select to an entry" becomes incomplete and must be rewritten, plus a new short section:

> **Photos from this date.** If you turn on photo look-back, keepsake reads the dates of photos in your library to find ones taken on the date you're viewing, and displays them on your Home screen. Photos are shown directly from your library — keepsake does not copy, store, or upload them, and reads nothing else about them. You can turn this off at any time in Settings.

### Hosted policy at keepsakejournal.app/privacy

Same text, same change, **same release**. CLAUDE.md requires the two to match, and App Review checks the URL.

### `MemoryJournal/CLAUDE.md`

Do **not** simply delete the "must not request photo-library access at all" rule. The rejection history is why the current code is shaped this way, and deleting it invites a regression. Rewrite it as a superseded entry, in the same style as the superseded time-zone rule:

> **The app must not request photo-library access at all — SUPERSEDED (Phase 7).** ~~`PhotosPicker` runs out-of-process…~~ Still true for *attaching* photos: `PhotosPicker` remains the only path for adding a photo to an entry, and it needs no permission. But photo look-back genuinely reads the library by capture date, which no out-of-process picker can do, so `NSPhotoLibraryUsageDescription` and a `.readWrite` request are back — for access the app actually uses, which is what 5.1.1(iv) requires.
> **The 5.1.1(iv) rules that still hold:** no screen may explain a permission and then trigger it. The onboarding toggle stores intent only and calls no Photos API; the prompt is triggered by the user tapping the in-context card on the Journal screen, at the point of use.

Then add a "Phase 7 decisions (recorded)" section covering: local-vs-UTC photo matching and why; the accepted capture-zone limitation; deterministic seeding and why random breaks; favourites-first / no-screenshots ranking; `.limited` handled explicitly; dismissals stored as identifiers only.

### App Store Connect

The privacy nutrition label should still be "no data collected" — nothing leaves the device — but **verify rather than assume** before submitting. Add a reviewer note explaining the photo permission and exactly where the prompt is triggered.

---

## Order and checkpoints

Phases 1 → 2 are invisible and fully testable: run the suite and be confident in the date math before any UI exists. Phase 3 is where it becomes visible. Phase 4 is small. Phase 5 must land before submission.

**Two testing notes:**

- The Simulator's stock library has a handful of photos with unhelpful dates. To see anything you need images whose EXIF dates fall on today's month/day in past years: write a JPEG with `kCGImagePropertyExifDateTimeOriginal` set, then `xcrun simctl addmedia booted <file>` — Photos files it on that day. Phase 3 was verified this way. Still worth a `-seedPhotoLookback` DEBUG launch argument, in the spirit of the existing ones.
- **Don't pass `-hasOnboarded NO`** to replay onboarding. Launch arguments live in `NSArgumentDomain`, which outranks everything the app writes, so finishing onboarding can't stick and the flow loops. Use the Dev tab's "Replay onboarding" button, or launch with no arguments after resetting.
- **Build Debug explicitly** when installing by hand: `xcodebuild build` uses the scheme's Release configuration, so `xcodebuild build && simctl install <Debug path>` silently installs a stale binary — and the DEBUG-only launch arguments won't exist in the Release build anyway.
- **Test the `.limited` path deliberately** by granting "Selected Photos". It is the state most likely to ship broken, because it looks exactly like "no photos found".

---

## Open risks

- **Review outcome is not certain.** The prompt is user-initiated and in-context, which is the best available position, but the onboarding toggle is still adjacent to it. Build so that removing the toggle is a one-screen change.
- **`PermissionStatus` gaining `.limited`** touches existing Settings code — small, but it is the one place Phase 2 reaches outside its own files.
- **Five-year mode on a new phone** may find nothing at all — and that is the exact user this feature exists for. Five-month mode (the default) will be dense. The feature under-delivers precisely for the long-term-reflection users who chose five years.
- **What a random photo actually is.** Screenshots, receipts, and parking-spot photos are handled by the filtering. Genuinely painful photos — an ex, a hospital visit, someone who has died — are not, and cannot be. The dismiss affordance and an easily-findable off switch are the mitigation; treat both as load-bearing, not polish.

---

## Ideas deliberately deferred

- **Tapping a photo opens the composer with that photo attached** ("you took this five years ago — write about it now"). This is probably the strongest conversion hook in the whole idea, but v1 opens a full-screen viewer instead. Revisit once the feature is proven.
- **Smarter ranking** — weighting toward photos with a location, or bursts of several photos close together (a burst suggests an event; a single shot at 11pm suggests a receipt).
- **More than one photo per slot.**
