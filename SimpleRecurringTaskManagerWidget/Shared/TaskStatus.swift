//
//  TaskStatus.swift
//  SimpleRecurringTaskManager
//

import Foundation

enum TaskStatus: String, Codable, CaseIterable {
    case pending
    case active
    case snoozed
    case deferred
    case doingNow = "doing_now"
    case checkingNow = "checking_now"
}
