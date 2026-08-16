//
//  ThemedButtonStyle.swift
//  SimpleTimer
//
//  Drop-in replacements for the system .bordered / .borderedProminent styles,
//  driven entirely by the current Theme. Swap sites just change the style
//  name (e.g. .buttonStyle(.borderedProminent) -> .buttonStyle(PrimaryButtonStyle())) —
//  no other view code changes.
//

import SwiftUI

/// Replaces .borderedProminent — a filled, high-emphasis call to action.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.theme) private var theme
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(theme.typography.buttonLabel)
            .foregroundStyle(theme.appTheme == .retro ? theme.colors.background : Color.white)
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: theme.metrics.cornerRadius, style: .continuous)
                    .fill(theme.colors.accent.opacity(isEnabled ? 1 : 0.4))
                    .shadow(
                        color: theme.colors.shadow,
                        radius: theme.metrics.shadowRadius,
                        x: theme.metrics.shadowOffset.width,
                        y: theme.metrics.shadowOffset.height
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: theme.metrics.cornerRadius, style: .continuous)
                    .stroke(theme.colors.border, lineWidth: theme.appTheme == .retro ? theme.metrics.borderWidth : 0)
            )
            .scaleEffect(configuration.isPressed ? theme.metrics.pressedScale : 1)
            .animation(theme.appTheme == .retro ? nil : .spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// Replaces .bordered — a lower-emphasis, outlined/tinted control.
struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.theme) private var theme
    @Environment(\.isEnabled) private var isEnabled
    var horizontalPadding: CGFloat = 20

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(theme.typography.buttonLabel)
            .foregroundStyle(theme.colors.accent.opacity(isEnabled ? 1 : 0.4))
            .padding(.vertical, 14)
            .padding(.horizontal, horizontalPadding)
            .background(
                RoundedRectangle(cornerRadius: theme.metrics.cornerRadius, style: .continuous)
                    .fill(theme.appTheme == .retro ? theme.colors.surface : theme.colors.accent.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: theme.metrics.cornerRadius, style: .continuous)
                    .stroke(theme.appTheme == .retro ? theme.colors.border : Color.clear, lineWidth: theme.metrics.borderWidth)
            )
            .scaleEffect(configuration.isPressed ? theme.metrics.pressedScale : 1)
            .animation(theme.appTheme == .retro ? nil : .spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// A bordered-style button tinted for destructive actions (delete, etc.).
struct DestructiveButtonStyle: ButtonStyle {
    @Environment(\.theme) private var theme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(theme.typography.buttonLabel)
            .foregroundStyle(theme.colors.destructive)
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: theme.metrics.cornerRadius, style: .continuous)
                    .fill(theme.appTheme == .retro ? theme.colors.surface : theme.colors.destructive.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: theme.metrics.cornerRadius, style: .continuous)
                    .stroke(theme.appTheme == .retro ? theme.colors.border : Color.clear, lineWidth: theme.metrics.borderWidth)
            )
            .scaleEffect(configuration.isPressed ? theme.metrics.pressedScale : 1)
            .animation(theme.appTheme == .retro ? nil : .spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// A SecondaryButtonStyle that renders as PrimaryButtonStyle when `isSelected`
/// is true — for option rows (e.g. quick-duration buttons) that need to show
/// which choice currently matches the underlying value.
struct SelectableButtonStyle: ButtonStyle {
    @Environment(\.theme) private var theme
    @Environment(\.isEnabled) private var isEnabled
    var isSelected: Bool
    var horizontalPadding: CGFloat = 20

    func makeBody(configuration: Configuration) -> some View {
        if isSelected {
            PrimaryButtonStyle().makeBody(configuration: configuration)
        } else {
            SecondaryButtonStyle(horizontalPadding: horizontalPadding).makeBody(configuration: configuration)
        }
    }
}

/// For icon+caption controls (e.g. the round Cancel/Pause glyphs in
/// ActiveTimerView) that already set their own foregroundStyle — this only
/// standardizes the press feedback across themes.
struct IconActionButtonStyle: ButtonStyle {
    @Environment(\.theme) private var theme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? theme.metrics.pressedScale : 1)
            .animation(theme.appTheme == .retro ? nil : .spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
