//
//  SpeechInputManager.swift
//  SimpleTimer
//

import Speech
import AVFoundation

@Observable
final class SpeechInputManager {
    var transcript = ""
    var isListening = false
    // Seeded from the current system status (reading this never prompts) so the
    // mic button can distinguish "never asked" from "denied" before the user
    // taps anything, instead of assuming unauthorized until a prompt fires.
    var authStatus: SFSpeechRecognizerAuthorizationStatus = SFSpeechRecognizer.authorizationStatus()
    var isAuthorized: Bool { authStatus == .authorized }

    /// User-facing message for the most recent failure to start listening — nil when
    /// there's nothing to show. Set instead of failing silently, so a denied audio
    /// session or unavailable recognizer surfaces as something the user can act on
    /// rather than a mic button that just does nothing when tapped.
    var lastError: String?

    private let recognizer = SFSpeechRecognizer()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var silenceTask: Task<Void, Never>?
    private var lastActivityAt = Date()

    func requestAuthorization() async {
        let status = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0) }
        }
        authStatus = status
    }

    func startListening() {
        guard !isListening else { return }
        guard recognizer?.isAvailable == true else {
            lastError = "Speech recognition isn't available right now. Check your internet connection and try again, or type the name instead."
            return
        }

        lastError = nil
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            request = SFSpeechAudioBufferRecognitionRequest()
            guard let request else { return }
            request.shouldReportPartialResults = true

            let node = audioEngine.inputNode
            node.installTap(onBus: 0, bufferSize: 1024, format: node.outputFormat(forBus: 0)) { [weak self] buffer, _ in
                self?.request?.append(buffer)
            }

            audioEngine.prepare()
            try audioEngine.start()
            isListening = true
            transcript = ""
            lastActivityAt = Date()
            startSilenceTimer()

            task = recognizer?.recognitionTask(with: request) { result, error in
                let text = result?.bestTranscription.formattedString
                let isDone = error != nil || result?.isFinal == true
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if let text, text != self.transcript {
                        self.transcript = text
                        self.lastActivityAt = Date()
                    }
                    if isDone { self.stopListening() }
                }
            }
        } catch {
            isListening = false
            lastError = "Couldn't start listening. Check your internet connection and try again, or type the name instead."
        }
    }

    private func startSilenceTimer() {
        silenceTask?.cancel()
        silenceTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(0.5))
                guard isListening else { break }
                if Date().timeIntervalSince(lastActivityAt) >= 2.0 {
                    stopListening()
                    break
                }
            }
        }
    }

    func stopListening() {
        silenceTask?.cancel()
        silenceTask = nil
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        isListening = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
