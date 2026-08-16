//
//  MileagePromptContainerView.swift
//  SimpleRecurringTaskManager
//
//  Presented full-screen by ContentView when any car's mileage is due (and no
//  task currently needs a Do Now decision — that takes priority). One car at a
//  time; saving that car's entry makes MileageEngine.isPromptDue false for it, so
//  the next car (if any) or dismissal follows automatically on the next render,
//  the same self-clearing pattern as DoNowContainerView.
//

import SwiftUI
import SwiftData

struct MileagePromptContainerView: View {
    @Environment(\.theme) private var theme
    @Query private var cars: [Car]
    @Binding var isPresented: Bool

    private var carsNeedingPrompt: [Car] {
        cars.filter { MileageEngine.isPromptDue(for: $0) }
    }

    var body: some View {
        Group {
            if let car = carsNeedingPrompt.first {
                MileagePromptView(car: car)
            } else {
                Color.clear
            }
        }
        .environment(\.theme, theme)
        .onChange(of: carsNeedingPrompt.isEmpty) { _, isEmpty in
            if isEmpty {
                isPresented = false
            }
        }
    }
}
