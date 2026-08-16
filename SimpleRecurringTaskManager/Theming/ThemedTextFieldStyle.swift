//
//  ThemedTextFieldStyle.swift
//  SimpleTimer
//
//  Replaces .textFieldStyle(.roundedBorder) with a themed equivalent. Built as
//  a plain View modifier (rather than a custom TextFieldStyle conformance,
//  which relies on an underscored SwiftUI API) so it's fully public API and
//  safe long-term.
//

import SwiftUI

private struct ThemedTextFieldModifier: ViewModifier {
    @Environment(\.theme) private var theme

    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .font(theme.typography.body)
            .foregroundStyle(theme.colors.primaryText)
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: theme.metrics.cornerRadius, style: .continuous)
                    .fill(theme.colors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: theme.metrics.cornerRadius, style: .continuous)
                    .stroke(theme.colors.border, lineWidth: max(theme.metrics.borderWidth, 1))
            )
    }
}

extension View {
    func themedTextField() -> some View {
        modifier(ThemedTextFieldModifier())
    }
}
