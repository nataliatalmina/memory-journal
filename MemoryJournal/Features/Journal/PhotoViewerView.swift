//
//  PhotoViewerView.swift
//  MemoryJournal
//
//  The full-screen look at a look-back photo, opened by tapping its row.
//
//  Presented as a SHEET, not pushed. Same reason the entry detail view is a
//  sheet (see JournalView): the custom bottom tab bar is added with
//  `.safeAreaInset` in RootTabView, so it sits on top of anything pushed inside
//  a tab and covers its lower content. A sheet floats above the bar.
//

import SwiftUI

struct PhotoViewerView: View {
    let date: Date
    let candidate: PhotoCandidate
    /// "Don't show this photo" — hides it for good and closes the viewer.
    let onDismissPhoto: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: Spacing.lg) {
                    Text(date.journalHeading())
                        .font(.kyoto(size: 24))
                        .foregroundStyle(Color.appPrimary)

                    // `scaledToFit` here rather than the row's fill crop: this is
                    // the screen for looking at the photo properly, so show all of
                    // it, whatever shape it is.
                    GeometryReader { proxy in
                        PhotoLibraryImage(localIdentifier: candidate.localIdentifier,
                                          displaySize: proxy.size)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: proxy.size.width, height: proxy.size.height)
                    }
                    .clipShape(.rect(cornerRadius: CornerRadius.card))

                    Text("from your photos")
                        .font(.kyotoItalic(size: 14))
                        .foregroundStyle(Color.appBodyText.opacity(0.7))
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.lg)
            }
            .toolbar {
                // Explicit leading/trailing rather than the semantic
                // `.destructiveAction` / `.confirmationAction` placements: on iOS
                // both of those resolve to the trailing edge, which put the two
                // buttons side by side and made "Done" look like a label for the
                // one next to it.
                ToolbarItem(placement: .topBarLeading) {
                    Button("Don't show this") {
                        onDismissPhoto()
                        dismiss()
                    }
                    .font(.kyoto(size: 15))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.kyoto(size: 17))
                }
            }
        }
        .presentationBackground(Color.appBackground)
    }
}
