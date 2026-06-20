//
//  MemoryTabBar.swift
//  MemoryJournal
//
//  The app's custom bottom tab bar, replacing the native iOS bar to match the
//  editorial design: hand-drawn book/notebook/list/gear icons above italic-serif
//  labels in Title Case. Active = deep teal, inactive = warm grey — which are the
//  design's #005363 / #525252, i.e. our existing `appPrimary` / `appBodyText`
//  tokens, so no new colours are introduced.
//
//  The icons are pre-coloured PNGs (an "_active" teal version and an "_inactive"
//  grey version per tab) in the asset catalog, so selecting a tab simply swaps
//  which image is shown — we don't tint them in code.
//

import SwiftUI

struct MemoryTabBar: View {
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(MemoryTabBar.items, id: \.tab) { item in
                TabBarButton(item: item,
                             isSelected: selection == item.tab) {
                    selection = item.tab
                }
            }
        }
        .padding(.top, Spacing.sm)
        .frame(maxWidth: .infinity)
        .background(alignment: .top) {
            // Off-white surface that extends down through the home-indicator area
            // (so the bar reaches the screen edge), with a hairline along the top to
            // separate it from content scrolling underneath.
            Color.appSurface
                .ignoresSafeArea(edges: .bottom)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color.appBodyText.opacity(0.08))
                        .frame(height: 0.5)
                }
        }
    }

    /// The tabs shown in the bar. The DEBUG-only dev tab is appended in debug
    /// builds (with an SF Symbol, since it has no custom artwork).
    static let items: [TabItem] = {
        var result: [TabItem] = [
            TabItem(tab: .journal, title: "Journal"),
            TabItem(tab: .calendar, title: "Calendar"),
            TabItem(tab: .prompts, title: "Prompts"),
            TabItem(tab: .settings, title: "Settings"),
        ]
        #if DEBUG
        result.append(TabItem(tab: .dev, title: "Dev", systemImage: "ladybug"))
        #endif
        return result
    }()
}

/// Describes one tab: its `AppTab`, the label, and how to draw its icon.
struct TabItem {
    let tab: AppTab
    let title: String
    /// When set, render this SF Symbol instead of the custom PNGs (the dev tab).
    var systemImage: String? = nil

    /// Asset-catalog names, e.g. "Journal_active" / "Journal_inactive".
    var activeImage: String { "\(title)_active" }
    var inactiveImage: String { "\(title)_inactive" }
}

private struct TabBarButton: View {
    let item: TabItem
    let isSelected: Bool
    let action: () -> Void

    private var tint: Color { isSelected ? Color.appPrimary : Color.appBodyText }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                icon
                    .frame(width: 30, height: 30)

                Text(item.title)
                    .font(.kyotoItalic(size: 14))
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)   // keeps long labels on one line at large type
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.xs)
            .contentShape(Rectangle())          // whole column is tappable
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.title)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    @ViewBuilder
    private var icon: some View {
        if let systemImage = item.systemImage {
            Image(systemName: systemImage)
                .font(.system(size: 22))
                .foregroundStyle(tint)
        } else {
            // Pre-coloured artwork; swap active/inactive on selection.
            Image(isSelected ? item.activeImage : item.inactiveImage)
                .resizable()
                .scaledToFit()
        }
    }
}

#Preview {
    @Previewable @State var selection: AppTab = .journal
    return VStack {
        Spacer()
        MemoryTabBar(selection: $selection)
    }
    .background(Color.appBackground)
}
