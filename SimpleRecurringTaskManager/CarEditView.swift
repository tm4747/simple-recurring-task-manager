//
//  CarEditView.swift
//  SimpleRecurringTaskManager
//
//  Reached from Settings > Cars. Phase 10 builds the full mileage-prompting and
//  estimation system — this is just the manual edit/entry surface it and the task
//  form (Phase 5) both read from.
//

import SwiftUI
import SwiftData

struct CarEditView: View {
    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var modelContext
    @Bindable var car: Car

    @State private var newMileageText = ""

    private var sortedEntries: [MileageEntry] {
        car.mileageEntries.sorted { $0.recordedAt > $1.recordedAt }
    }

    var body: some View {
        Form {
            Section {
                TextField("Car Name", text: $car.name)
                    .listRowBackground(theme.colors.surface)
            } header: {
                Text("Name")
            }

            Section {
                HStack {
                    TextField("Current Mileage", text: $newMileageText)
                        .keyboardType(.numberPad)
                    Button("Save") { recordMileage() }
                        .disabled(Int(newMileageText) == nil)
                }
                .listRowBackground(theme.colors.surface)

                if let estimate = car.monthlyMileageEstimate {
                    HStack {
                        Text("Monthly Estimate")
                            .foregroundStyle(theme.colors.primaryText)
                        Spacer()
                        Text("\(estimate) mi")
                            .foregroundStyle(theme.colors.secondaryText)
                    }
                    .listRowBackground(theme.colors.surface)
                }
            } header: {
                Text("Mileage")
            }

            if !sortedEntries.isEmpty {
                Section {
                    ForEach(sortedEntries) { entry in
                        HStack {
                            Text(entry.recordedAt, format: .dateTime.month().day().year())
                                .foregroundStyle(theme.colors.primaryText)
                            Spacer()
                            Text("\(entry.mileage) mi")
                                .foregroundStyle(theme.colors.secondaryText)
                        }
                    }
                    .listRowBackground(theme.colors.surface)
                } header: {
                    Text("Mileage History")
                }
            }
        }
        .themedFormChrome()
        .navigationTitle(car.name)
    }

    private func recordMileage() {
        guard let mileage = Int(newMileageText) else { return }
        let entry = MileageEntry(car: car, mileage: mileage, isUserEntered: true)
        modelContext.insert(entry)
        newMileageText = ""
    }
}

#Preview {
    NavigationStack {
        CarEditView(car: Car(name: "My Honda Civic", monthlyMileageEstimate: 800))
    }
    .environment(\.theme, .resolve(.light))
    .modelContainer(for: [Car.self, MileageEntry.self], inMemory: true)
}
