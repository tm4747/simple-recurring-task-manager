//
//  DismissKeyboardOnTap.swift
//  SimpleRecurringTaskManager
//

import SwiftUI

extension View {
    /// Dismisses the keyboard when the user taps anywhere else on screen — the
    /// standard iOS "tap outside to dismiss" pattern. Uses simultaneousGesture
    /// rather than onTapGesture so it never intercepts taps meant for buttons,
    /// text fields, or other controls beneath it; it just also resigns whichever
    /// responder is currently first (a no-op if nothing is focused), regardless
    /// of which specific field that is — so one call covers every text input on
    /// the screen without each needing its own FocusState wired in here.
    func dismissKeyboardOnTap() -> some View {
        simultaneousGesture(
            TapGesture().onEnded {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        )
    }
}
