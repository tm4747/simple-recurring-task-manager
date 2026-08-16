//
//  SpokenLabelField.swift
//  SimpleTimer
//
//  Shared text+voice input field used by both CreateTimerView's optional
//  "Spoken Label" and ActiveTimerView's required save-preset label. Owns its
//  own SpeechInputManager, mic-permission alert, and the animated
//  "Listening..." indicator so both call sites stay in sync.
//

import SwiftUI
import UIKit
import Speech

struct SpokenLabelField: View {
    @Environment(\.theme) private var theme
    @Binding var text: String
    var placeholder: String
    var isFocused: FocusState<Bool>.Binding

    @State private var speech = SpeechInputManager()
    @State private var showMicPermissionAlert = false

    private var micIconName: String {
        if speech.isListening { return "mic.fill" }
        if speech.authStatus == .denied || speech.authStatus == .restricted { return "mic.slash" }
        return "mic"
    }

    private var micAccessibilityLabel: String {
        if speech.isListening { return "Stop voice input" }
        if speech.authStatus == .denied || speech.authStatus == .restricted { return "Microphone access denied" }
        return "Start voice input"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                TextField(placeholder, text: $text)
                    .themedTextField()
                    .focused(isFocused)
                Button {
                    isFocused.wrappedValue = false
                    handleMicTap()
                } label: {
                    Image(systemName: micIconName)
                        .foregroundStyle(speech.isListening ? theme.colors.destructive : theme.colors.secondaryText)
                        .imageScale(.large)
                }
                .buttonStyle(IconActionButtonStyle())
                .accessibilityLabel(micAccessibilityLabel)
            }
            if speech.isListening {
                listeningIndicator
            }
        }
        .alert("Microphone Access Needed", isPresented: $showMicPermissionAlert) {
            Button("Open Settings") {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Simple Recurring Task Manager needs microphone and speech recognition access to turn your voice into text. You can enable this in Settings.")
        }
        .onChange(of: speech.transcript) { _, newValue in
            if !newValue.isEmpty { text = newValue }
        }
        // Guarantees the audio session/engine is torn down if this field's screen
        // is dismissed mid-listen (e.g. the completion sheet dismissing after Save).
        .onDisappear { speech.stopListening() }
    }

    // TimelineView-driven so the "Listening..." cadence doesn't need its own
    // Timer/Combine plumbing — the dot count is just a function of wall-clock time.
    private var listeningIndicator: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            let dotCount = Int(context.date.timeIntervalSinceReferenceDate / 0.5) % 3 + 1
            Text("Listening" + String(repeating: ".", count: dotCount))
                .font(theme.typography.caption)
                .foregroundStyle(theme.colors.secondaryText)
        }
    }

    // Requests speech authorization lazily on first tap, rather than the moment
    // this field appears — asking before the user has done anything to explain
    // why reads as an unprompted permission grab and hurts opt-in rates.
    private func handleMicTap() {
        switch speech.authStatus {
        case .authorized:
            if speech.isListening { speech.stopListening() } else { speech.startListening() }
        case .notDetermined:
            Task {
                await speech.requestAuthorization()
                if speech.authStatus == .authorized { speech.startListening() }
            }
        case .denied, .restricted:
            showMicPermissionAlert = true
        @unknown default:
            break
        }
    }
}
