//
//  ScreenHeaderBar.swift
//  SimpleTimer
//
//  A fixed (non-scrolling) title row used in place of the system navigation
//  bar's title. UINavigationBar's .principal toolbar slot is a centered,
//  width-constrained container — giving its content a leading-aligned,
//  full-width frame does NOT push it to the true left edge. Rendering the
//  title ourselves, in the screen's own content instead of the nav bar
//  chrome, is the only way to get a genuinely left-aligned title sharing a
//  row with the trailing ThemeSwitchButton.
//

import SwiftUI

struct ScreenHeaderBar<TrailingAccessory: View>: View {
    @Environment(\.theme) private var theme

    let title: String
    var onBack: (() -> Void)?
    @ViewBuilder var trailingAccessory: () -> TrailingAccessory

    init(
        title: String,
        onBack: (() -> Void)? = nil,
        @ViewBuilder trailingAccessory: @escaping () -> TrailingAccessory = { EmptyView() }
    ) {
        self.title = title
        self.onBack = onBack
        self.trailingAccessory = trailingAccessory
    }

    var body: some View {
        HStack(spacing: 12) {
            if let onBack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(theme.colors.accent)
                }
                .accessibilityLabel("Back")
                .accessibilityIdentifier("ScreenHeaderBar.Back")
            }
            Text(title)
                .font(.system(size: 32, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 12)
            trailingAccessory()
            ThemeSwitchButton()
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(theme.colors.background)
    }
}
