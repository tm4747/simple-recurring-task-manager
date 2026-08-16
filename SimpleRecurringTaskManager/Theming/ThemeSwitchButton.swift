//
//  ThemeSwitchButton.swift
//  SimpleRecurringTaskManager
//
//  Circular theme-cycling control for the top-right of a screen's title bar.
//  Mirrors ../SimpleTimer's ThemeSwitchButton (same bordered-surface circle, same
//  sun / moon / retro-pixel-invader crossfade, same Light -> Dark -> Retro -> Light
//  cycle order), adapted to this app's AppSettings model instead of UserSettings —
//  reads/writes through the same AppSettings record as SettingsView's picker, so
//  either control stays in sync with the other.
//

import SwiftUI
import SwiftData

struct ThemeSwitchButton: View {
    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var modelContext
    @Query private var allSettings: [AppSettings]

    private var currentAppTheme: AppTheme {
        allSettings.first?.theme ?? .light
    }

    private var nextAppTheme: AppTheme {
        let cases = AppTheme.allCases
        let index = cases.firstIndex(of: currentAppTheme) ?? 0
        return cases[(index + 1) % cases.count]
    }

    var body: some View {
        Button {
            let settings = AppSettings.shared(in: modelContext)
            settings.theme = nextAppTheme
            try? modelContext.save()
        } label: {
            ZStack {
                Circle()
                    .fill(theme.colors.surface)
                    .overlay(Circle().stroke(theme.colors.border, lineWidth: theme.metrics.borderWidth))

                icon(for: .light, systemImage: "sun.max.fill")
                icon(for: .dark, systemImage: "moon.fill")
                retroInvader
            }
            .frame(width: 36, height: 36)
            .animation(.easeInOut(duration: 0.3), value: currentAppTheme)
        }
        .buttonStyle(IconActionButtonStyle())
        .accessibilityLabel("Switch to \(nextAppTheme.displayName) mode")
    }

    // Only the active theme's icon is visible — inactive ones sit rotated,
    // shrunk, and transparent so the .animation above crossfades between them.
    @ViewBuilder
    private func icon(for appTheme: AppTheme, systemImage: String) -> some View {
        let isActive = currentAppTheme == appTheme
        Image(systemName: systemImage)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(theme.colors.primaryText)
            .rotationEffect(.degrees(isActive ? 0 : (appTheme == .light ? -90 : 90)))
            .scaleEffect(isActive ? 1 : 0.5)
            .opacity(isActive ? 1 : 0)
    }

    private var retroInvader: some View {
        let isActive = currentAppTheme == .retro
        return RetroInvaderShape()
            .fill(theme.colors.primaryText)
            .frame(width: 16, height: 16 * 8 / 11)
            .rotationEffect(.degrees(isActive ? 0 : 90))
            .scaleEffect(isActive ? 1 : 0.5)
            .opacity(isActive ? 1 : 0)
    }
}

/// The 11x8 pixel-invader glyph from the website's ThemeToggle SVG, redrawn as
/// a scalable Shape instead of a fixed-size vector asset.
private struct RetroInvaderShape: Shape {
    private static let unitRects: [(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat)] = [
        (2, 0, 1, 1), (8, 0, 1, 1),
        (3, 1, 1, 1), (7, 1, 1, 1),
        (2, 2, 7, 1),
        (1, 3, 2, 1), (4, 3, 3, 1), (8, 3, 2, 1),
        (0, 4, 11, 1),
        (0, 5, 1, 1), (2, 5, 7, 1), (10, 5, 1, 1),
        (0, 6, 1, 1), (2, 6, 1, 1), (8, 6, 1, 1), (10, 6, 1, 1),
        (3, 7, 1, 1), (7, 7, 1, 1),
    ]

    func path(in rect: CGRect) -> Path {
        let scaleX = rect.width / 11
        let scaleY = rect.height / 8
        var path = Path()
        for r in Self.unitRects {
            path.addRect(CGRect(
                x: rect.minX + r.x * scaleX,
                y: rect.minY + r.y * scaleY,
                width: r.w * scaleX,
                height: r.h * scaleY
            ))
        }
        return path
    }
}

#Preview {
    HStack(spacing: 16) {
        ThemeSwitchButton()
    }
    .padding()
    .environment(\.theme, .resolve(.light))
    .modelContainer(for: [AppSettings.self], inMemory: true)
}
