//
//  Font+Theme.swift
//  MemoryJournal
//
//  Typography tokens — the app's serif type system in one place. Views reference
//  these named styles (`.kyoto(size:)` / `.kyotoItalic(size:)`) rather than raw
//  font names, so the whole app's type can change from this single file.
//
//  The custom font is **PP Kyoto**. The `.otf` files live in
//  `DesignSystem/Fonts/` and are registered via `UIAppFonts` in the project-root
//  `Info.plist`. The PostScript names (confirmed from the files) match the
//  filenames: "PPKyoto-Medium" and "PPKyoto-MediumItalic".
//
//  `Font.custom(_:size:)` scales with Dynamic Type automatically, so these still
//  respect the user's text-size setting.
//

import SwiftUI

extension Font {
    /// Upright serif — headings, body, general text. (PP Kyoto Medium.)
    static func kyoto(size: CGFloat) -> Font {
        .custom("PPKyoto-Medium", size: size)
    }

    /// Italic serif — the signature style used on button labels
    /// ("Create your memory", "Continue", …) and the tab bar labels.
    /// (PP Kyoto Medium Italic.)
    static func kyotoItalic(size: CGFloat) -> Font {
        .custom("PPKyoto-MediumItalic", size: size)
    }

    /// Bold serif — heavier than the Medium body, used to make entry titles stand
    /// out from the body text. (PP Kyoto Bold; registered in Info.plist.)
    static func kyotoBold(size: CGFloat) -> Font {
        .custom("PPKyoto-Bold", size: size)
    }
}
