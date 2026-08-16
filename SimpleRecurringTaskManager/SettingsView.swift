//
//  SettingsView.swift
//  SimpleRecurringTaskManager
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.theme) private var theme

    // Kept in sync with AppSettings.selectedTheme so a theme change made via the
    // header bar's ThemeSwitchButton (same AppSettings record) is reflected here
    // instead of being silently overwritten by save() the next time some other
    // field on this screen changes. Mirrors ../SimpleTimer's SettingsView pattern.
    @Query private var allSettings: [AppSettings]
    @Query(sort: \SnoozeOption.sortOrder) private var snoozeOptions: [SnoozeOption]
    @Query private var cars: [Car]

    @State private var selectedTheme: AppTheme = .light
    @State private var alarmSound: AlarmSound = .systemDefault
    @State private var alarmDurationSeconds = 300
    @State private var defaultSnoozeSeconds = 300
    @State private var eveningTime = AppSettings.time(hour: 18, minute: 0)
    @State private var weekendDefaultTime = AppSettings.nextWeekday(.saturday, hour: 9, minute: 0)
    @State private var widgetEnabled = true
    @State private var hasLoaded = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScreenHeaderBar(title: "Settings")
                settingsForm
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .themedScreenBackground()
        .onAppear { loadIfNeeded() }
        .onChange(of: selectedTheme) { _, _ in save() }
        .onChange(of: alarmSound) { _, _ in save() }
        .onChange(of: alarmDurationSeconds) { _, _ in save() }
        .onChange(of: defaultSnoozeSeconds) { _, _ in save() }
        .onChange(of: eveningTime) { _, _ in save() }
        .onChange(of: weekendDefaultTime) { _, _ in save() }
        .onChange(of: widgetEnabled) { _, _ in save() }
        .onChange(of: allSettings.first?.selectedTheme) { _, newValue in
            guard hasLoaded, let newValue, let newTheme = AppTheme(rawValue: newValue) else { return }
            selectedTheme = newTheme
        }
    }

    private var settingsForm: some View {
        Form {
            Section {
                Picker("Alarm Sound", selection: $alarmSound) {
                    ForEach(AlarmSound.allCases) { sound in
                        Text(sound.displayName).tag(sound)
                    }
                }
                .listRowBackground(theme.colors.surface)

                DurationStepperRow(label: "Alarm Duration", seconds: $alarmDurationSeconds)
                    .listRowBackground(theme.colors.surface)
            } header: {
                Text("Alarm")
            }

            Section {
                DurationStepperRow(label: "Default Snooze", seconds: $defaultSnoozeSeconds)
                    .listRowBackground(theme.colors.surface)

                ForEach(snoozeOptions) { option in
                    SnoozeOptionRow(option: option, excluding: otherSnoozeDurations(excluding: option))
                        .listRowBackground(theme.colors.surface)
                }
            } header: {
                Text("Snooze")
            } footer: {
                Text("Hold the Snooze button in the Do Now view to choose one of these durations.")
            }

            Section {
                DatePicker("This Evening", selection: $eveningTime, in: eveningRange, displayedComponents: .hourAndMinute)
                    .listRowBackground(theme.colors.surface)

                Picker("This Weekend Day", selection: weekendDayBinding) {
                    Text("Saturday").tag(AppSettings.WeekendDay.saturday)
                    Text("Sunday").tag(AppSettings.WeekendDay.sunday)
                }
                .pickerStyle(.segmented)
                .listRowBackground(theme.colors.surface)

                DatePicker("This Weekend Time", selection: weekendTimeBinding, in: weekendTimeRange, displayedComponents: .hourAndMinute)
                    .listRowBackground(theme.colors.surface)
            } header: {
                Text("Defer Defaults")
            }

            Section {
                Picker("Theme", selection: $selectedTheme) {
                    ForEach(AppTheme.allCases) { appTheme in
                        Text(appTheme.displayName).tag(appTheme)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(theme.colors.surface)
            } header: {
                Text("Appearance")
            }

            Section {
                Toggle("Home Screen Widget", isOn: $widgetEnabled)
                    .listRowBackground(theme.colors.surface)
            } header: {
                Text("Widget")
            } footer: {
                Text("Shows your next 3 upcoming tasks. Add or remove it from the Home Screen using the standard iOS widget flow.")
            }

            if !cars.isEmpty {
                Section {
                    ForEach(cars) { car in
                        NavigationLink(car.name) {
                            CarEditView(car: car)
                        }
                        .foregroundStyle(theme.colors.primaryText)
                        .listRowBackground(theme.colors.surface)
                    }
                } header: {
                    Text("Cars")
                }
            }
        }
        .themedFormChrome()
    }

    // MARK: - Weekend day/time bindings

    private var currentWeekendDay: AppSettings.WeekendDay {
        Calendar.current.component(.weekday, from: weekendDefaultTime) == AppSettings.WeekendDay.saturday.rawValue ? .saturday : .sunday
    }

    private var weekendDayBinding: Binding<AppSettings.WeekendDay> {
        Binding(
            get: { currentWeekendDay },
            set: { newDay in
                let components = Calendar.current.dateComponents([.hour, .minute], from: weekendDefaultTime)
                weekendDefaultTime = AppSettings.nextWeekday(newDay, hour: components.hour ?? 9, minute: components.minute ?? 0)
            }
        )
    }

    private var weekendTimeBinding: Binding<Date> {
        Binding(
            get: { weekendDefaultTime },
            set: { newTime in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newTime)
                weekendDefaultTime = AppSettings.nextWeekday(currentWeekendDay, hour: components.hour ?? 9, minute: components.minute ?? 0)
            }
        )
    }

    // MARK: - Ranges

    private var eveningRange: ClosedRange<Date> {
        AppSettings.time(hour: 14, minute: 0)...AppSettings.time(hour: 23, minute: 0)
    }

    // "This weekend" spans Sat 6 AM – Sun 9 PM; each day's own picker is
    // constrained to its slice of that window (Saturday keeps to Saturday, Sunday
    // keeps to Sunday — the range's own bounds enforce the overall window's
    // start/end).
    private var weekendTimeRange: ClosedRange<Date> {
        let calendar = Calendar.current
        let day = weekendDefaultTime
        switch currentWeekendDay {
        case .saturday:
            let lower = calendar.date(bySettingHour: 6, minute: 0, second: 0, of: day) ?? day
            let upper = calendar.date(bySettingHour: 23, minute: 59, second: 0, of: day) ?? day
            return lower...upper
        case .sunday:
            let lower = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: day) ?? day
            let upper = calendar.date(bySettingHour: 21, minute: 0, second: 0, of: day) ?? day
            return lower...upper
        }
    }

    private func otherSnoozeDurations(excluding option: SnoozeOption) -> Set<Int> {
        Set(snoozeOptions.filter { $0.id != option.id }.map(\.durationSeconds))
    }

    // MARK: - Persistence

    private func loadIfNeeded() {
        guard !hasLoaded else { return }
        hasLoaded = true
        let settings = AppSettings.shared(in: modelContext)
        selectedTheme = settings.theme
        alarmSound = AlarmSound(rawValue: settings.alarmSound) ?? .systemDefault
        alarmDurationSeconds = settings.alarmDurationSeconds
        defaultSnoozeSeconds = settings.defaultSnoozeSeconds
        eveningTime = settings.eveningTime
        weekendDefaultTime = settings.weekendDefaultTime
        widgetEnabled = settings.widgetEnabled
    }

    private func save() {
        guard hasLoaded else { return }
        let settings = AppSettings.shared(in: modelContext)
        settings.theme = selectedTheme
        settings.alarmSound = alarmSound.rawValue
        settings.alarmDurationSeconds = alarmDurationSeconds
        settings.defaultSnoozeSeconds = defaultSnoozeSeconds
        settings.eveningTime = eveningTime
        settings.weekendDefaultTime = weekendDefaultTime
        settings.widgetEnabled = widgetEnabled
        try? modelContext.save()
    }
}

// A labeled "- value +" row for adjusting a duration via DurationSteps.
private struct DurationStepperRow: View {
    @Environment(\.theme) private var theme
    var label: String
    @Binding var seconds: Int
    var excluding: Set<Int> = []

    var body: some View {
        HStack {
            Text(label).foregroundStyle(theme.colors.primaryText)
            Spacer()
            Button {
                seconds = DurationSteps.step(from: seconds, direction: -1, excluding: excluding)
            } label: {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.colors.accent)

            Text(seconds.formattedAsDuration)
                .font(theme.typography.body.monospacedDigit())
                .foregroundStyle(theme.colors.secondaryText)
                .frame(minWidth: 92)
                .multilineTextAlignment(.center)

            Button {
                seconds = DurationSteps.step(from: seconds, direction: 1, excluding: excluding)
            } label: {
                Image(systemName: "plus.circle")
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.colors.accent)
        }
    }
}

// Same "- value +" row, but bound directly to a SnoozeOption model instance
// instead of local @State — keeps its label in sync with the duration it shows.
private struct SnoozeOptionRow: View {
    @Environment(\.theme) private var theme
    var option: SnoozeOption
    var excluding: Set<Int> = []

    var body: some View {
        HStack {
            Text(option.label).foregroundStyle(theme.colors.primaryText)
            Spacer()
            Button { step(-1) } label: {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.colors.accent)

            Text(option.durationSeconds.formattedAsDuration)
                .font(theme.typography.body.monospacedDigit())
                .foregroundStyle(theme.colors.secondaryText)
                .frame(minWidth: 92)
                .multilineTextAlignment(.center)

            Button { step(1) } label: {
                Image(systemName: "plus.circle")
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.colors.accent)
        }
    }

    private func step(_ direction: Int) {
        let newValue = DurationSteps.step(from: option.durationSeconds, direction: direction, excluding: excluding)
        option.durationSeconds = newValue
        option.label = newValue.formattedAsDuration
    }
}

#Preview {
    SettingsView()
        .environment(\.theme, .resolve(.light))
        .modelContainer(for: [AppSettings.self, SnoozeOption.self, Car.self], inMemory: true)
}
