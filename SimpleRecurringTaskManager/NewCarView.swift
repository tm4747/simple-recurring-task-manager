//
//  NewCarView.swift
//  SimpleRecurringTaskManager
//
//  Reached from the task form's car picker when creating a Car Maintenance task
//  with no existing car to select. Distinct from CarEditView (Settings > Cars) —
//  this is just first-time creation, not the ongoing edit/mileage-history screen.
//

import SwiftUI
import SwiftData

struct NewCarView: View {
    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var mileageText = ""
    @State private var monthlyEstimateText = ""

    var onCreate: (Car) -> Void

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // Monthly estimate is only required once a current mileage is entered — see
    // the PRD's "New car form" spec.
    private var canSave: Bool {
        guard !trimmedName.isEmpty else { return false }
        guard !mileageText.isEmpty else { return true }
        return Int(monthlyEstimateText) != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeaderBar(title: "New Car", onBack: { dismiss() })
            Form {
                Section {
                    TextField("Car Name", text: $name)
                        .listRowBackground(theme.colors.surface)
                } header: {
                    Text("Name")
                }

                Section {
                    TextField("Current Mileage", text: $mileageText)
                        .keyboardType(.numberPad)
                        .listRowBackground(theme.colors.surface)
                    TextField("Estimated Miles per Month", text: $monthlyEstimateText)
                        .keyboardType(.numberPad)
                        .listRowBackground(theme.colors.surface)
                } header: {
                    Text("Mileage")
                } footer: {
                    Text("Both are optional, but estimated miles per month is required if you enter a current mileage.")
                }
            }
            .themedFormChrome()

            Button("Save") { save() }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!canSave)
                .padding()
        }
        .themedScreenBackground()
        .toolbar(.hidden, for: .navigationBar)
    }

    private func save() {
        guard canSave else { return }
        let mileage = Int(mileageText)
        let car = Car(name: trimmedName, initialMileage: mileage, monthlyMileageEstimate: Int(monthlyEstimateText))
        modelContext.insert(car)
        if let mileage {
            modelContext.insert(MileageEntry(car: car, mileage: mileage, isUserEntered: true))
        }
        onCreate(car)
        dismiss()
    }
}

#Preview {
    NewCarView { _ in }
        .environment(\.theme, .resolve(.light))
        .modelContainer(for: [Car.self, MileageEntry.self], inMemory: true)
}
