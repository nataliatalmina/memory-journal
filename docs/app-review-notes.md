# App Store Connect — submission notes for photo look-back

Written 7 September 2026, for the first build that ships Phase 7.

This is the material to paste into App Store Connect, plus the checks to run
first. Everything here is for a human to submit — nothing in this file happens
automatically.

---

## Before you submit

- [ ] **Privacy policy copies match.** Run `python3 scripts/compare-privacy-policy.py`. It must print IDENTICAL. Then confirm the hosted page is actually live at https://www.keepsakejournal.app/privacy-ios with the new "Photos from this date" section and the 7 September 2026 effective date — a deploy that didn't run is the easy way to fail this.
- [ ] **Policy URL in App Store Connect is `/privacy-ios`**, not `/privacy`. The latter is the desktop app's separate policy and describes different mechanisms.
- [ ] **Usage string is present in the build.** `INFOPLIST_KEY_NSPhotoLibraryUsageDescription` is set in both Debug and Release configurations; verify it appears in the archived build's Info.plist, not just in the project file.
- [ ] **Walk the permission path on a device with a real photo library**, in both look-back modes, including declining the prompt and choosing "Selected Photos".
- [ ] **Privacy nutrition label:** confirm it still declares no data collection. Nothing leaves the device — the app reads photo metadata and displays images locally — but the label is a claim under Apple's definitions, so re-read them rather than assuming this answer carries over.

## Reviewer note (paste into "Notes" in App Store Connect)

> keepsake is a local-only journal. This version adds an optional feature called
> photo look-back.
>
> The app shows entries written on today's date in previous months or years. Where
> the user wrote nothing on one of those dates, photo look-back can show a photo
> they took that day instead. It is off by default.
>
> How to see it:
> 1. On the second onboarding screen ("keep your cherished memories"), switch on
>    "photos from this date". This screen only stores the preference — it does not
>    request any permission.
> 2. On the Journal tab, the first empty look-back slot shows a card reading
>    "Nothing written on this date. Tap to look for a photo — keepsake will ask to
>    read your photo library."
> 3. Tapping that card raises the iOS photo-library permission prompt. This is the
>    only place in the app that requests photo-library access, and it is requested
>    at the point of use, with no screen in front of it explaining or arguing for
>    the permission.
> 4. Granting access shows photos taken on those dates. The test device needs
>    photos whose capture dates fall on today's day-of-month in earlier months or
>    years, or there will be nothing to find.
>
> Why the app needs photo-library access: it searches the library by capture date.
> PHPickerViewController cannot do this — it returns only what the user picks and
> cannot be queried by date. Access is requested as .readWrite because the Photos
> framework has no read-only level; the app never writes to the library.
>
> Photos shown this way are never copied into the app, stored, or uploaded. They
> are rendered directly from the library. If the user hides a photo, the app stores
> only that photo's local identifier so it is not shown again; that list is
> clearable in Settings.
>
> The feature can be switched off at any time in Settings, which stops the app
> reading the library.

## Context for whoever handles a rejection

Build 1.0 (3) was rejected under guideline 5.1.1(iv) for a pre-permission screen
with "Enable Camera / Photo Library / Microphone" buttons and a "Maybe later"
escape, and for requesting photo-library access the app never used. Both causes
are addressed:

- The access is now genuinely used — it *is* the feature.
- No screen explains the permission and then triggers it. The onboarding and
  Settings toggles store intent only and call no Photos API; the request happens
  on a tap, in the slot the photo would occupy.

**If it is rejected again on this point**, the smallest fix that keeps the feature
working is to remove the onboarding toggle and leave the Settings toggle plus the
in-context card. That is a single-screen change (`ViewModeSelectionView`), which
is why the toggle was built to be removable in one edit. Don't remove the
in-context card — it is the request itself.
