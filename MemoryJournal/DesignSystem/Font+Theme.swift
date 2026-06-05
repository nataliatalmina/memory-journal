//
//  Font+Theme.swift
//  MemoryJournal
//
//  Typography tokens — the app's serif type system in one place.
//
//  ┌──────────────────────────────────────────────────────────────────────┐
//  │ TODO(PP Kyoto): swap the built-in serif fallback for the real font.    │
//  │                                                                        │
//  │ Right now these helpers return the closest *built-in* serif so the     │
//  │ layout is visible. Once the custom "PP Kyoto" files are added we point  │
//  │ them at the real font instead (see "What I need from you" below).      │
//  └──────────────────────────────────────────────────────────────────────┘
//
//  WHAT I NEED FROM YOU to finish the font swap:
//   1. The two font files exported from Figma:
//        • PPKyoto-Medium.otf        (upright serif — headings, body, general text)
//        • PPKyoto-MediumItalic.otf  (italic serif — buttons, tab labels)
//      Drop them into this DesignSystem folder (or a Fonts/ subfolder).
//   2. The exact PostScript names inside each .otf. The filename and the
//      PostScript name often differ. To find them: open each file in Font Book
//      (double-click the .otf), then View ▸ Show Font Info — the "PostScript
//      name" is the string we must use in `.custom(...)` below.
//   Once I have those, I will: register them under `UIAppFonts` in Info.plist,
//   confirm they load, and replace the two TODO lines below with the real
//   PostScript names. Views won't change — they already call `.kyoto(...)`.
//

import SwiftUI

extension Font {
    /// Upright serif — headings, body, general text.
    static func kyoto(size: CGFloat) -> Font {
        // TODO(PP Kyoto): return .custom("PPKyoto-Medium", size: size)
        .system(size: size, design: .serif)
    }

    /// Italic serif — the signature style used on button labels
    /// ("Create your memory", "Continue", …) and the tab bar labels.
    static func kyotoItalic(size: CGFloat) -> Font {
        // TODO(PP Kyoto): return .custom("PPKyoto-MediumItalic", size: size)
        .system(size: size, design: .serif).italic()
    }
}
