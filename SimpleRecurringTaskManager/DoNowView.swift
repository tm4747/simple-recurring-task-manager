//
//  DoNowView.swift
//  SimpleRecurringTaskManager
//
//  The action screen for a single due task. Standard-task actions (Phase 8):
//  Done, I'll Do It Now (+ the "Are you done?" follow-up once its countdown
//  expires), Snooze, Do It This Evening/Tomorrow/This-or-Next-Weekend. Check-first
//  actions (Phase 9): I'll Check It Now (+ the "Did you check it?" follow-up,
//  which for "I checked it" branches again into "does it need to be done?").
//  Every action stops the alarm (interacting with it is what "until the user
//  interacts" means) and reschedules notifications around whatever new date the
//  action implies.
//

import SwiftUI
import SwiftData

struct DoNowView: View {
    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var modelContext
    let task: TaskItem
    var showBackButton: Bool = false
    var onBack: (() -> Void)? = nil

    @Query(sort: \SnoozeOption.sortOrder) private var snoozeOptions: [SnoozeOption]
    @Query private var allSettings: [AppSettings]

    @State private var isShowingDoneNote = false
    @State private var doneNoteText = ""
    @State private var isShowingTimeTakesToDoPrompt = false
    @State private var pendingDoNowSeconds = 1800
    @State private var isShowingNeedsDoneCheck = false
    // Set after "I Didn't Do It" / "I Didn't Check It" — hides the Done button for
    // the rest of this Do Now session, per the PRD's "same options minus Done"
    // rule. Deliberately local @State, not persisted on the task: a fresh due
    // cycle later (new snooze/defer arriving, a brand-new DoNowView instance)
    // should offer Done normally again, not carry this forward forever.
    @State private var hideDoneButton = false
    @FocusState private var isNoteFocused: Bool

    private var settings: AppSettings { allSettings.first ?? AppSettings() }

    private var isAwaitingDoneCheck: Bool {
        task.status == .doingNow && (task.doingNowDeadline ?? .distantFuture) <= Date()
    }

    private var isAwaitingCheckResult: Bool {
        task.status == .checkingNow && (task.doingNowDeadline ?? .distantFuture) <= Date()
    }

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeaderBar(title: "Do Now", onBack: showBackButton ? onBack : nil)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    taskSummary
                    if isAwaitingDoneCheck {
                        areYouDonePrompt
                    } else if isAwaitingCheckResult {
                        if isShowingNeedsDoneCheck {
                            needsDoneCheckPrompt
                        } else {
                            didYouCheckItPrompt
                        }
                    } else {
                        standardActions
                    }
                }
                .padding()
            }
        }
        .themedScreenBackground()
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { AlarmPlayer.shared.stop() }
        .sheet(isPresented: $isShowingDoneNote) { doneNoteSheet }
        .sheet(isPresented: $isShowingTimeTakesToDoPrompt) { timeTakesToDoSheet }
    }

    // MARK: - Sections

    private var taskSummary: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(task.title)
                .font(theme.typography.title)
                .foregroundStyle(theme.colors.primaryText)
            if let category = task.category {
                Text(category.name)
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.secondaryText)
            }
        }
    }

    private var areYouDonePrompt: some View {
        VStack(spacing: 12) {
            Text("Are you done?")
                .font(theme.typography.headline)
                .foregroundStyle(theme.colors.primaryText)
            Button("Yes, Done") { handleYesDone() }
                .buttonStyle(PrimaryButtonStyle())
                .frame(maxWidth: .infinity)
            Button("I Didn't Do It") { handleDidNotDoIt() }
                .buttonStyle(SecondaryButtonStyle())
                .frame(maxWidth: .infinity)
        }
    }

    private var didYouCheckItPrompt: some View {
        VStack(spacing: 12) {
            Text("Did you check it?")
                .font(theme.typography.headline)
                .foregroundStyle(theme.colors.primaryText)
            Button("I Checked It") { isShowingNeedsDoneCheck = true }
                .buttonStyle(PrimaryButtonStyle())
                .frame(maxWidth: .infinity)
            Button("I Didn't Check It") { handleDidNotCheckIt() }
                .buttonStyle(SecondaryButtonStyle())
                .frame(maxWidth: .infinity)
        }
    }

    private var needsDoneCheckPrompt: some View {
        VStack(spacing: 12) {
            Text("Does it need to be done?")
                .font(theme.typography.headline)
                .foregroundStyle(theme.colors.primaryText)
            Button("It Needs to Be Done") { handleNeedsToBeDone() }
                .buttonStyle(PrimaryButtonStyle())
                .frame(maxWidth: .infinity)
            Button("It Does Not Need to Be Done") { handleDoesNotNeedToBeDone() }
                .buttonStyle(SecondaryButtonStyle())
                .frame(maxWidth: .infinity)
        }
    }

    private var standardActions: some View {
        VStack(spacing: 12) {
            if !hideDoneButton {
                Button("Done") {
                    doneNoteText = ""
                    isShowingDoneNote = true
                }
                .buttonStyle(PrimaryButtonStyle())
                .frame(maxWidth: .infinity)
            }

            Button("I'll Do It Now") { startDoingNow() }
                .buttonStyle(SecondaryButtonStyle())
                .frame(maxWidth: .infinity)

            if task.isCheckFirst {
                Button("I'll Check It Now") { startCheckingNow() }
                    .buttonStyle(SecondaryButtonStyle())
                    .frame(maxWidth: .infinity)
            }

            HoldMenuButton(title: "Snooze", action: { snooze(seconds: settings.defaultSnoozeSeconds) }) {
                ForEach(snoozeOptions) { option in
                    Button(option.label) { snooze(seconds: option.durationSeconds) }
                }
            }

            Button("Do It This Evening") { deferTo(eveningTarget()) }
                .buttonStyle(SecondaryButtonStyle())
                .frame(maxWidth: .infinity)

            HoldMenuButton(title: "Do It Tomorrow", action: { deferTo(tomorrowTarget(daysAhead: 1)) }) {
                Button("Do It in 2 Days") { deferTo(tomorrowTarget(daysAhead: 2)) }
                Button("Do It in 3 Days") { deferTo(tomorrowTarget(daysAhead: 3)) }
                Button("Do It in 4 Days") { deferTo(tomorrowTarget(daysAhead: 4)) }
            }

            HoldMenuButton(title: weekendButtonLabel, action: { deferTo(weekendTarget(offsetWeekends: 0)) }) {
                Button("1 Weekend From Now") { deferTo(weekendTarget(offsetWeekends: 1)) }
                Button("2 Weekends From Now") { deferTo(weekendTarget(offsetWeekends: 2)) }
            }
        }
    }

    private var doneNoteSheet: some View {
        VStack(spacing: 0) {
            ScreenHeaderBar(title: "Add a Note", onBack: { isShowingDoneNote = false })
            VStack(alignment: .leading, spacing: 16) {
                SpokenLabelField(text: $doneNoteText, placeholder: "Optional note", isFocused: $isNoteFocused)
                Button("Save") {
                    isShowingDoneNote = false
                    markDone(note: doneNoteText)
                }
                .buttonStyle(PrimaryButtonStyle())
                .frame(maxWidth: .infinity)
            }
            .padding()
            Spacer()
        }
        .themedScreenBackground()
    }

    private var timeTakesToDoSheet: some View {
        VStack(spacing: 0) {
            ScreenHeaderBar(title: "How Long Will It Take?", onBack: { isShowingTimeTakesToDoPrompt = false })
            VStack(spacing: 16) {
                HourMinutePicker(totalSeconds: $pendingDoNowSeconds)
                Button("Start") {
                    isShowingTimeTakesToDoPrompt = false
                    beginDoingNowCountdown(seconds: pendingDoNowSeconds)
                }
                .buttonStyle(PrimaryButtonStyle())
                .frame(maxWidth: .infinity)
            }
            .padding()
            Spacer()
        }
        .themedScreenBackground()
    }

    // MARK: - Actions

    private func markDone(note: String? = nil, wasDone: Bool = true) {
        let trimmedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        let mileageAtCompletion = task.car.flatMap { MileageEngine.estimatedCurrentMileage(for: $0) }
        let doneItem = TaskDoneItem(
            task: task,
            wasDone: wasDone,
            note: (trimmedNote?.isEmpty == false) ? trimmedNote : nil,
            mileageAtCompletion: mileageAtCompletion
        )
        modelContext.insert(doneItem)
        task.isOverdue = false
        task.status = .pending
        task.snoozeUntil = nil
        task.doingNowDeadline = nil
        task.updatedAt = Date()
        if let car = task.car {
            task.nextDue = MileageEngine.recalculatedNextDue(for: task, car: car)
        } else {
            task.nextDue = RecurrenceEngine.recalculatedNextDue(for: task)
        }
        rescheduleNotifications(fireDate: task.nextDue)
        AlarmPlayer.shared.stop()
        doneNoteText = ""
    }

    private func startDoingNow() {
        if let existing = task.timeTakesToDo {
            beginDoingNowCountdown(seconds: Int(existing))
        } else {
            pendingDoNowSeconds = 1800
            isShowingTimeTakesToDoPrompt = true
        }
    }

    private func beginDoingNowCountdown(seconds: Int) {
        task.timeTakesToDo = TimeInterval(seconds)
        task.status = .doingNow
        let deadline = Date().addingTimeInterval(TimeInterval(seconds))
        task.doingNowDeadline = deadline
        task.updatedAt = Date()
        NotificationScheduler.shared.scheduleDeadlinePrompt(
            taskID: task.id,
            title: task.title,
            body: "Are you done?",
            fireDate: deadline,
            alarmSound: currentAlarmSound()
        )
        AlarmPlayer.shared.stop()
    }

    private func handleYesDone() {
        markDone()
    }

    private func handleDidNotDoIt() {
        task.isOverdue = true
        task.status = .pending
        task.doingNowDeadline = nil
        task.updatedAt = Date()
        hideDoneButton = true
        AlarmPlayer.shared.stop()
    }

    private func startCheckingNow() {
        guard let checkSeconds = task.timeTakesToCheck else { return }
        task.status = .checkingNow
        let deadline = Date().addingTimeInterval(checkSeconds)
        task.doingNowDeadline = deadline
        task.updatedAt = Date()
        NotificationScheduler.shared.scheduleDeadlinePrompt(
            taskID: task.id,
            title: task.title,
            body: "Did you check it?",
            fireDate: deadline,
            alarmSound: currentAlarmSound()
        )
        AlarmPlayer.shared.stop()
    }

    private func handleNeedsToBeDone() {
        isShowingNeedsDoneCheck = false
        task.status = .pending
        task.doingNowDeadline = nil
        task.updatedAt = Date()
    }

    private func handleDoesNotNeedToBeDone() {
        isShowingNeedsDoneCheck = false
        markDone(wasDone: false)
    }

    private func handleDidNotCheckIt() {
        task.isOverdue = true
        task.status = .pending
        task.doingNowDeadline = nil
        task.updatedAt = Date()
        hideDoneButton = true
        AlarmPlayer.shared.stop()
    }

    private func snooze(seconds: Int) {
        task.status = .snoozed
        task.snoozeUntil = Date().addingTimeInterval(TimeInterval(seconds))
        task.isOverdue = true
        task.updatedAt = Date()
        rescheduleNotifications(fireDate: task.snoozeUntil)
        AlarmPlayer.shared.stop()
    }

    private func deferTo(_ date: Date) {
        task.status = .deferred
        task.nextDue = date
        task.snoozeUntil = nil
        task.isOverdue = true
        task.updatedAt = Date()
        rescheduleNotifications(fireDate: date)
        AlarmPlayer.shared.stop()
    }

    private func rescheduleNotifications(fireDate: Date?) {
        NotificationScheduler.shared.reschedule(for: task, fireDate: fireDate, alarmSound: currentAlarmSound())
    }

    private func currentAlarmSound() -> AlarmSound {
        AlarmSound(rawValue: settings.alarmSound) ?? .systemDefault
    }

    // MARK: - Target date calculations

    private func eveningTarget() -> Date {
        let calendar = Calendar.current
        let now = Date()
        let timeComponents = calendar.dateComponents([.hour, .minute], from: settings.eveningTime)
        var candidate = calendar.date(bySettingHour: timeComponents.hour ?? 18, minute: timeComponents.minute ?? 0, second: 0, of: now) ?? now
        if candidate <= now {
            candidate = calendar.date(byAdding: .day, value: 1, to: candidate) ?? candidate
        }
        return candidate
    }

    // "at original task time" per the PRD — uses this task's firstOccurrence
    // time-of-day.
    private func tomorrowTarget(daysAhead: Int) -> Date {
        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute], from: task.firstOccurrence)
        let targetDay = calendar.date(byAdding: .day, value: daysAhead, to: Date()) ?? Date()
        return calendar.date(bySettingHour: timeComponents.hour ?? 9, minute: timeComponents.minute ?? 0, second: 0, of: targetDay) ?? targetDay
    }

    // Sat 1 AM - Sun 12:59 AM per the PRD's button-label rule.
    private var isInWeekendWindow: Bool {
        let calendar = Calendar.current
        let now = Date()
        let weekday = calendar.component(.weekday, from: now)
        let hour = calendar.component(.hour, from: now)
        return (weekday == 7 && hour >= 1) || weekday == 1
    }

    private var weekendButtonLabel: String {
        isInWeekendWindow ? "Do It Next Weekend" : "Do It This Weekend"
    }

    // offsetWeekends 0 is always the very next future occurrence of the
    // configured weekend day/time — the button-label logic above only changes
    // what that's *called*, never which date it actually targets.
    private func weekendTarget(offsetWeekends: Int) -> Date {
        let calendar = Calendar.current
        let weekendTime = settings.weekendDefaultTime
        let weekday = calendar.component(.weekday, from: weekendTime)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: weekendTime)
        let now = Date()
        let currentWeekday = calendar.component(.weekday, from: now)
        let daysUntil = (weekday - currentWeekday + 7) % 7
        let candidateDay = calendar.date(byAdding: .day, value: daysUntil, to: now) ?? now
        var components = calendar.dateComponents([.year, .month, .day], from: candidateDay)
        components.hour = timeComponents.hour
        components.minute = timeComponents.minute
        guard var base = calendar.date(from: components) else { return now }
        if base <= now {
            base = calendar.date(byAdding: .day, value: 7, to: base) ?? base
        }
        return calendar.date(byAdding: .weekOfYear, value: offsetWeekends, to: base) ?? base
    }
}

// Tap = `action`, hold = reveals `content`'s menu — SwiftUI's Menu(primaryAction:)
// maps exactly onto the PRD's "tap = default, hold = options" buttons (Snooze, Do
// It Tomorrow, Do It This/Next Weekend), styled to match PrimaryButtonStyle.
private struct HoldMenuButton<Content: View>: View {
    @Environment(\.theme) private var theme
    let title: String
    let action: () -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        Menu {
            content()
        } label: {
            Text(title)
                .font(theme.typography.buttonLabel)
                .foregroundStyle(theme.appTheme == .retro ? theme.colors.background : Color.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: theme.metrics.cornerRadius, style: .continuous)
                        .fill(theme.colors.accent)
                )
        } primaryAction: {
            action()
        }
    }
}

#Preview {
    DoNowView(task: TaskItem(title: "Clean gutters", recurrenceType: .annually, firstOccurrence: Date()))
        .environment(\.theme, .resolve(.light))
        .modelContainer(for: [TaskItem.self, TaskDoneItem.self, SnoozeOption.self, AppSettings.self], inMemory: true)
}
