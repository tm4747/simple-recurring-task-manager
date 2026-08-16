//
//  AlarmSound.swift
//  SimpleRecurringTaskManager
//
//  The selectable alarm sounds. Only `displayName`/`rawValue` matter until Phase 7
//  wires actual sound-file playback and notification sounds — this enum is the
//  single source of truth both will read from.
//

import Foundation

enum AlarmSound: String, CaseIterable, Identifiable {
    case systemDefault = "default"
    case chime
    case bell
    case siren

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .systemDefault: return "System Default"
        case .chime: return "Chime"
        case .bell: return "Bell"
        case .siren: return "Siren"
        }
    }
}
