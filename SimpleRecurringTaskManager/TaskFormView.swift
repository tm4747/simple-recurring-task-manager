//
//  TaskFormView.swift
//  SimpleRecurringTaskManager
//
//  Create and edit both go through this one form. Editing pre-populates every
//  @State from `taskToEdit`; saving recalculates next_due (anchored to the most
//  recent completion, if any — see RecurrenceEngine) either way.
//

import SwiftUI
import SwiftData

/// How a brand-new task's schedule gets seeded — only relevant at creation time
/// (see TaskFormView.schedulingSection), since an existing task's schedule is
/// already anchored to its real completion history.
private enum ScheduleBasis: Hashable {
    /// The user directly states when the task is next due — the original,
    /// only behavior before the other two options existed.
    case nextOccurrence
    /// The user states when they last did it; next_due is computed from that
    /// by stepping the recurrence cadence forward, same as completing the task
    /// normally would.
    case lastTimeDone
    /// Shorthand for "I'm doing this for the first time right now" — lastTimeDone
    /// pinned to the current moment, no date to pick.
    case startNow
}

struct TaskFormView: View {
    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Category.createdAt) private var categories: [Category]
    @Query private var cars: [Car]

    var taskToEdit: TaskItem?

    @State private var title = ""
    @State private var selectedCategory: Category?
    @State private var isCheckFirst = false
    @State private var recurrenceType: RecurrenceType = .weekly
    @State private var recurrenceWeekNumber = 1
    @State private var recurrenceWeekday = 1
    @State private var recurrenceWeekdays: Set<Int> = []
    @State private var firstOccurrence = Date()
    @State private var scheduleBasis: ScheduleBasis = .nextOccurrence
    @State private var lastTimeDoneDate = Date()
    @State private var hasTimeTakesToDo = false
    @State private var timeTakesToDoSeconds = 1800
    @State private var timeTakesToCheckSeconds = 900
    @State private var selectedCar: Car?
    @State private var mileageTriggerText = ""
    @State private var timeTriggerMonthsText = ""

    @State private var isShowingNewCategory = false
    @State private var isShowingNewCar = false
    @State private var isShowingDeleteConfirmation = false
    @FocusState private var isTitleFocused: Bool

    private static let weekdaySymbols = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    private static let weekNumberLabels = ["1st", "2nd", "3rd", "4th", "Last"]

    private var isEditing: Bool { taskToEdit != nil }

    private var isCarMaintenance: Bool {
        selectedCategory?.isSystem == true && selectedCategory?.name == DefaultDataSeeder.carMaintenanceCategoryName
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var mileageTrigger: Int? { Int(mileageTriggerText) }
    private var timeTriggerMonths: Int? { Int(timeTriggerMonthsText) }

    private var canSave: Bool {
        guard !trimmedTitle.isEmpty else { return false }
        if isCarMaintenance {
            guard selectedCar != nil else { return false }
            return mileageTrigger != nil || timeTriggerMonths != nil
        }
        if recurrenceType == .specificWeekdays {
            return !recurrenceWeekdays.isEmpty
        }
        return true
    }

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeaderBar(title: isEditing ? "Edit Task" : "New Task", onBack: { dismiss() })
            Form {
                titleSection
                categorySection
                if isCarMaintenance {
                    carMaintenanceSection
                } else {
                    recurrenceSection
                }
                schedulingSection
                if isEditing {
                    deleteSection
                }
            }
            .themedFormChrome()

            Button(isEditing ? "Save Changes" : "Create Task") { save() }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!canSave)
                .padding()
        }
        .themedScreenBackground()
        .toolbar(.hidden, for: .navigationBar)
        .dismissKeyboardOnTap()
        .sheet(isPresented: $isShowingNewCategory) {
            NewCategoryView { category in
                selectedCategory = category
            }
            .environment(\.theme, theme)
        }
        .sheet(isPresented: $isShowingNewCar) {
            NewCarView { car in
                selectedCar = car
            }
            .environment(\.theme, theme)
        }
        .confirmationDialog(
            "Delete This Task?",
            isPresented: $isShowingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { deleteTask() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This can't be undone.")
        }
        // "No cars exist when selecting Car Maintenance category: redirect to car
        // creation flow before task creation continues" — per the PRD's edge
        // cases. Only fires the moment the category switches to Car Maintenance,
        // not on every re-render, so dismissing NewCarView without saving doesn't
        // immediately reopen it.
        .onChange(of: selectedCategory) { _, _ in
            if isCarMaintenance && cars.isEmpty {
                isShowingNewCar = true
            }
        }
        .onAppear { loadIfNeeded() }
    }

    // MARK: - Sections

    private var titleSection: some View {
        Section {
            SpokenLabelField(text: $title, placeholder: "Task Title", isFocused: $isTitleFocused)
                .listRowBackground(theme.colors.surface)
        } header: {
            Text("Title")
        }
    }

    private var categorySection: some View {
        Section {
            Picker("Category", selection: $selectedCategory) {
                Text("Uncategorized").tag(Category?.none)
                ForEach(categories) { category in
                    Text(category.name).tag(Category?.some(category))
                }
            }
            .listRowBackground(theme.colors.surface)

            Button {
                isShowingNewCategory = true
            } label: {
                Label("New Category", systemImage: "folder.badge.plus")
            }
            .foregroundStyle(theme.colors.accent)
            .listRowBackground(theme.colors.surface)

            Toggle("Check First", isOn: $isCheckFirst)
                .listRowBackground(theme.colors.surface)
        } header: {
            Text("Category")
        } footer: {
            Text("\"Check First\" adds an \"I'll Check It Now\" option that lets you inspect before deciding whether the task actually needs doing.")
        }
    }

    private var recurrenceSection: some View {
        Section {
            Picker("Repeats", selection: $recurrenceType) {
                ForEach(RecurrenceType.allCases.filter { $0 != .byMileage }, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .listRowBackground(theme.colors.surface)

            switch recurrenceType {
            case .nthWeekdayOfMonth:
                Picker("Week", selection: $recurrenceWeekNumber) {
                    ForEach(1...5, id: \.self) { number in
                        Text(Self.weekNumberLabels[number - 1]).tag(number)
                    }
                }
                .listRowBackground(theme.colors.surface)
                Picker("Weekday", selection: $recurrenceWeekday) {
                    ForEach(1...7, id: \.self) { weekday in
                        Text(Self.weekdaySymbols[weekday - 1]).tag(weekday)
                    }
                }
                .listRowBackground(theme.colors.surface)
            case .specificWeekdays:
                weekdayMultiSelect
                    .listRowBackground(theme.colors.surface)
            default:
                EmptyView()
            }
        } header: {
            Text("Recurrence")
        }
    }

    private var weekdayMultiSelect: some View {
        HStack(spacing: 6) {
            ForEach(1...7, id: \.self) { weekday in
                let isSelected = recurrenceWeekdays.contains(weekday)
                Button {
                    if isSelected { recurrenceWeekdays.remove(weekday) } else { recurrenceWeekdays.insert(weekday) }
                } label: {
                    Text(Self.weekdaySymbols[weekday - 1])
                        .font(theme.typography.caption)
                }
                .buttonStyle(SelectableButtonStyle(isSelected: isSelected, horizontalPadding: 8))
            }
        }
    }

    private var carMaintenanceSection: some View {
        Section {
            Picker("Car", selection: $selectedCar) {
                Text("Select a Car").tag(Car?.none)
                ForEach(cars) { car in
                    Text(car.name).tag(Car?.some(car))
                }
            }
            .listRowBackground(theme.colors.surface)

            Button {
                isShowingNewCar = true
            } label: {
                Label("New Car", systemImage: "car.fill")
            }
            .foregroundStyle(theme.colors.accent)
            .listRowBackground(theme.colors.surface)

            TextField("Mileage Trigger (e.g. 5000)", text: $mileageTriggerText)
                .keyboardType(.numberPad)
                .listRowBackground(theme.colors.surface)

            TextField("Time Trigger in Months (e.g. 24)", text: $timeTriggerMonthsText)
                .keyboardType(.numberPad)
                .listRowBackground(theme.colors.surface)
        } header: {
            Text("Car Maintenance")
        } footer: {
            Text("At least one trigger is required. With both set, the alarm fires at whichever comes first.")
        }
    }

    private var schedulingSection: some View {
        Section {
            if isEditing {
                DatePicker("First Occurrence", selection: $firstOccurrence)
                    .listRowBackground(theme.colors.surface)
            } else {
                Picker("Schedule Based On", selection: $scheduleBasis) {
                    Text("Next Occurrence").tag(ScheduleBasis.nextOccurrence)
                    Text("Last Time Done").tag(ScheduleBasis.lastTimeDone)
                    Text("Start Now").tag(ScheduleBasis.startNow)
                }
                .pickerStyle(.segmented)
                .listRowBackground(theme.colors.surface)

                switch scheduleBasis {
                case .nextOccurrence:
                    DatePicker("Next Occurrence", selection: $firstOccurrence)
                        .listRowBackground(theme.colors.surface)
                case .lastTimeDone:
                    DatePicker("Last Time Done", selection: $lastTimeDoneDate)
                        .listRowBackground(theme.colors.surface)
                case .startNow:
                    EmptyView()
                }
            }

            Toggle("Set Time to Do", isOn: $hasTimeTakesToDo)
                .listRowBackground(theme.colors.surface)
            if hasTimeTakesToDo {
                HourMinutePicker(totalSeconds: $timeTakesToDoSeconds)
                    .listRowBackground(theme.colors.surface)
            }

            if isCheckFirst {
                Text("Time to Check")
                    .foregroundStyle(theme.colors.primaryText)
                    .listRowBackground(theme.colors.surface)
                HourMinutePicker(totalSeconds: $timeTakesToCheckSeconds)
                    .listRowBackground(theme.colors.surface)
            }
        } header: {
            Text("Schedule")
        } footer: {
            if !isEditing {
                Text(scheduleFooterText)
            }
        }
    }

    private var scheduleFooterText: String {
        switch scheduleBasis {
        case .nextOccurrence:
            return "The task is due at exactly the date/time you pick here."
        case .lastTimeDone:
            return "The task's next due date is calculated from this date using its recurrence — same as if you'd marked it Done then."
        case .startNow:
            return "Treated as if you just did it — the next due date is calculated from right now using its recurrence."
        }
    }

    private var deleteSection: some View {
        Section {
            Button("Delete Task", role: .destructive) {
                isShowingDeleteConfirmation = true
            }
            .listRowBackground(theme.colors.surface)
        }
    }

    // MARK: - Load / Save

    private func loadIfNeeded() {
        guard let task = taskToEdit else { return }
        title = task.title
        selectedCategory = task.category
        isCheckFirst = task.isCheckFirst
        recurrenceType = task.recurrenceType
        recurrenceWeekNumber = task.recurrenceWeekNumber ?? 1
        recurrenceWeekday = task.recurrenceWeekday ?? 1
        recurrenceWeekdays = Set(task.recurrenceWeekdays ?? [])
        firstOccurrence = task.firstOccurrence
        if let timeTakesToDo = task.timeTakesToDo {
            hasTimeTakesToDo = true
            timeTakesToDoSeconds = Int(timeTakesToDo)
        }
        timeTakesToCheckSeconds = Int(task.timeTakesToCheck ?? 900)
        selectedCar = task.car
        mileageTriggerText = task.mileageTrigger.map(String.init) ?? ""
        timeTriggerMonthsText = task.timeTriggerMonths.map(String.init) ?? ""
    }

    private func save() {
        guard canSave else { return }
        let task = taskToEdit ?? TaskItem(title: trimmedTitle, recurrenceType: recurrenceType, firstOccurrence: firstOccurrence)
        if taskToEdit == nil {
            modelContext.insert(task)
        }

        task.title = trimmedTitle
        task.category = selectedCategory
        task.isCheckFirst = isCheckFirst
        task.recurrenceType = isCarMaintenance ? .byMileage : recurrenceType
        task.recurrenceWeekNumber = recurrenceType == .nthWeekdayOfMonth ? recurrenceWeekNumber : nil
        task.recurrenceWeekday = recurrenceType == .nthWeekdayOfMonth ? recurrenceWeekday : nil
        task.recurrenceWeekdays = recurrenceType == .specificWeekdays ? Array(recurrenceWeekdays).sorted() : nil
        task.timeTakesToDo = hasTimeTakesToDo ? TimeInterval(timeTakesToDoSeconds) : nil
        task.timeTakesToCheck = isCheckFirst ? TimeInterval(timeTakesToCheckSeconds) : nil
        task.car = isCarMaintenance ? selectedCar : nil
        task.mileageTrigger = isCarMaintenance ? mileageTrigger : nil
        task.timeTriggerMonths = isCarMaintenance ? timeTriggerMonths : nil
        task.updatedAt = Date()

        // "Last Time Done" / "Start Now" seed a backdated completion so next_due
        // comes out of the normal recurrence math (same as marking the task Done
        // would), instead of the user having to compute the next occurrence by
        // hand. Only meaningful at creation — an existing task's schedule is
        // already anchored to its real completion history.
        let seedCompletionDate: Date? = {
            guard !isEditing else { return nil }
            switch scheduleBasis {
            case .nextOccurrence: return nil
            case .lastTimeDone: return lastTimeDoneDate
            case .startNow: return Date()
            }
        }()

        if let seedCompletionDate {
            let mileageAtCompletion = task.car.flatMap { MileageEngine.estimatedCurrentMileage(for: $0, asOf: seedCompletionDate) }
            modelContext.insert(TaskDoneItem(
                task: task,
                completedAt: seedCompletionDate,
                wasDone: true,
                mileageAtCompletion: mileageAtCompletion
            ))
            if let car = task.car {
                task.nextDue = MileageEngine.recalculatedNextDue(
                    for: task,
                    car: car,
                    justCompleted: (completedAt: seedCompletionDate, mileageAtCompletion: mileageAtCompletion)
                )
            } else {
                task.nextDue = RecurrenceEngine.recalculatedNextDue(for: task, justCompletedAt: seedCompletionDate)
            }
            // Represents "the first future alarm" — with a seeded completion,
            // that's the freshly computed next_due, not the (past) completion
            // date itself.
            task.firstOccurrence = task.nextDue ?? seedCompletionDate
        } else {
            task.firstOccurrence = firstOccurrence
            if let car = task.car {
                task.nextDue = MileageEngine.recalculatedNextDue(for: task, car: car)
            } else {
                task.nextDue = RecurrenceEngine.recalculatedNextDue(for: task)
            }
        }

        let settings = AppSettings.shared(in: modelContext)
        let alarmSound = AlarmSound(rawValue: settings.alarmSound) ?? .systemDefault
        NotificationScheduler.shared.reschedule(for: task, fireDate: task.nextDue, alarmSound: alarmSound)

        dismiss()
    }

    private func deleteTask() {
        guard let task = taskToEdit else { return }
        NotificationScheduler.shared.cancel(taskID: task.id)
        modelContext.delete(task)
        dismiss()
    }
}

private extension RecurrenceType {
    var displayName: String {
        switch self {
        case .oneTime: return "One Time"
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .biweekly: return "Biweekly"
        case .monthly: return "Monthly"
        case .biannually: return "Every 6 Months"
        case .annually: return "Annually"
        case .firstOfMonth: return "1st of Month"
        case .nthWeekdayOfMonth: return "Nth Weekday of Month"
        case .specificWeekdays: return "Specific Weekdays"
        case .byMileage: return "By Mileage"
        }
    }
}

#Preview {
    TaskFormView()
        .environment(\.theme, .resolve(.light))
        .modelContainer(for: [TaskItem.self, Category.self, Car.self, MileageEntry.self], inMemory: true)
}
