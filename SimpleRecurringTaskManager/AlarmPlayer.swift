//
//  AlarmPlayer.swift
//  SimpleRecurringTaskManager
//
//  Foreground alarm playback — loops the selected sound for up to
//  alarmDurationSeconds or until `stop()` is called (the PRD's "until the user
//  interacts"). Backgrounded delivery is NotificationScheduler's job instead;
//  this class only ever runs while the app is frontmost.
//

import AVFoundation
import AudioToolbox

final class AlarmPlayer {
    static let shared = AlarmPlayer()
    private init() {}

    private var player: AVAudioPlayer?
    private var systemSoundTimer: Timer?
    private var stopWorkItem: DispatchWorkItem?

    func play(sound: AlarmSound, durationSeconds: Int) {
        stop()

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, options: [.duckOthers])
        try? session.setActive(true)

        if let fileName = sound.fileName, let url = Bundle.main.url(forResource: fileName, withExtension: nil) {
            player = try? AVAudioPlayer(contentsOf: url)
            player?.numberOfLoops = -1
            player?.play()
        } else {
            // No bundled file for System Default — loop a built-in system alert
            // sound instead (1005 is the standard "SMS Received" alert tone).
            AudioServicesPlaySystemSound(1005)
            systemSoundTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
                AudioServicesPlaySystemSound(1005)
            }
        }

        let workItem = DispatchWorkItem { [weak self] in self?.stop() }
        stopWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(durationSeconds), execute: workItem)
    }

    func stop() {
        player?.stop()
        player = nil
        systemSoundTimer?.invalidate()
        systemSoundTimer = nil
        stopWorkItem?.cancel()
        stopWorkItem = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
