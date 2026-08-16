//
//  AlarmSound.swift
//  SimpleRecurringTaskManager
//
//  The selectable alarm sounds, backed by real bundled .wav files (borrowed from
//  ../SimpleBoxingTimer's Sounds) — .wav rather than .mp3 because
//  UNNotificationSound only reliably supports Linear PCM/IMA4/µLaw/aLaw audio in a
//  caf/aiff/wav container, not mp3.
//

import Foundation
import UserNotifications

enum AlarmSound: String, CaseIterable, Identifiable {
    case systemDefault = "default"
    case chime
    case bellClassic
    case bellHeavy

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .systemDefault: return "System Default"
        case .chime: return "Chime"
        case .bellClassic: return "Bell (Classic)"
        case .bellHeavy: return "Bell (Heavy)"
        }
    }

    /// Bundle resource file name, or nil for the system default sound (which has
    /// no file — `.default` covers notifications, and foreground playback falls
    /// back to a built-in system sound ID instead).
    var fileName: String? {
        switch self {
        case .systemDefault: return nil
        case .chime: return "bell1.wav"
        case .bellClassic: return "bell_classic.wav"
        case .bellHeavy: return "bell_heavy.wav"
        }
    }

    var notificationSound: UNNotificationSound {
        guard let fileName else { return .default }
        return UNNotificationSound(named: UNNotificationSoundName(fileName))
    }
}
