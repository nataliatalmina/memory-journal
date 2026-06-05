//
//  ScreenPlaceholder.swift
//  MemoryJournal
//
//  Temporary stand-in used by each tab during Phase 0: just the screen's name,
//  centered on the app background. It exists so the skeleton is visible and the
//  design tokens are exercised; the real screens replace it in later phases.
//

import SwiftUI

struct ScreenPlaceholder: View {
    let title: String

    var body: some View {
        // `ZStack` layers views back-to-front: the background fills the screen,
        // the title sits on top, centered by default.
        ZStack {
            Color.appBackground
                .ignoresSafeArea()   // paint the background edge-to-edge, under the bars
            Text(title)
                .font(.kyoto(size: 32))
                .foregroundStyle(Color.appPrimary)
        }
    }
}

#Preview {
    ScreenPlaceholder(title: "journal")
}
