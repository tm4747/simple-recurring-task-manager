//
//  MileagePromptView.swift
//  SimpleRecurringTaskManager
//
//  Non-dismissable card shown by MileagePromptContainerView when a car's mileage
//  is due per its schedule (see MileageEngine.isPromptDue). Saving recalculates
//  next_due for every byMileage task tied to the car and reschedules their
//  notifications, since a new data point can shift the monthly average.
//

import SwiftUI
import SwiftData

struct MileagePromptView: View {
    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var modelContext
    let car: Car
    @Query private var allSettings: [AppSettings]

    @State private var mileageText = ""

    var body: some View {
        VStack {
            Spacer()
            VStack(spacing: 16) {
                Text("What's \(car.name)'s Current Mileage?")
                    .font(theme.typography.headline)
                    .foregroundStyle(theme.colors.primaryText)
                    .multilineTextAlignment(.center)

                TextField("Current Mileage", text: $mileageText)
                    .themedTextField()
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)

                Button("Save") { save() }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(Int(mileageText) == nil)
                    .frame(maxWidth: .infinity)
            }
            .padding(24)
            .themedCard()
            .padding()
            Spacer()
        }
        .themedScreenBackground()
        .dismissKeyboardOnTap()
        .onAppear {
            mileageText = (MileageEngine.estimatedCurrentMileage(for: car).map(String.init)) ?? ""
        }
    }

    private func save() {
        guard let mileage = Int(mileageText) else { return }
        let entry = MileageEntry(car: car, mileage: mileage, isUserEntered: true)
        modelContext.insert(entry)
        MileageEngine.backfillEstimatedEntries(for: car, through: entry, context: modelContext)

        let settings = allSettings.first ?? AppSettings()
        let sound = AlarmSound(rawValue: settings.alarmSound) ?? .systemDefault
        for task in car.tasks where task.recurrenceType == .byMileage {
            task.nextDue = MileageEngine.recalculatedNextDue(for: task, car: car)
            NotificationScheduler.shared.reschedule(for: task, fireDate: task.nextDue, alarmSound: sound)
        }
    }
}

#Preview {
    MileagePromptView(car: Car(name: "My Honda Civic", monthlyMileageEstimate: 800))
        .environment(\.theme, .resolve(.light))
        .modelContainer(for: [Car.self, MileageEntry.self, TaskItem.self, AppSettings.self], inMemory: true)
}
