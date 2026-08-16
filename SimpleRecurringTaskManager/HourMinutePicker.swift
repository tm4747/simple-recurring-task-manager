//
//  HourMinutePicker.swift
//  SimpleRecurringTaskManager
//
//  Two wheel Pickers (hours / minutes in 5-minute steps) bound to a total-seconds
//  Int — used for time_takes_to_do / time_takes_to_check on the task form (capped
//  at 72h per the PRD) and the "how long will it take?" prompt in the Do Now flow.
//

import SwiftUI

struct HourMinutePicker: View {
    @Binding var totalSeconds: Int
    var maxHours: Int = 72

    private var hours: Int { totalSeconds / 3600 }
    private var minutes: Int { (totalSeconds % 3600) / 60 }

    private var hoursBinding: Binding<Int> {
        Binding(get: { hours }, set: { totalSeconds = $0 * 3600 + minutes * 60 })
    }

    private var minutesBinding: Binding<Int> {
        Binding(get: { minutes }, set: { totalSeconds = hours * 3600 + $0 * 60 })
    }

    var body: some View {
        HStack {
            Picker("Hours", selection: hoursBinding) {
                ForEach(0...maxHours, id: \.self) { hour in
                    Text("\(hour) hr").tag(hour)
                }
            }
            .pickerStyle(.wheel)
            Picker("Minutes", selection: minutesBinding) {
                ForEach(Array(stride(from: 0, to: 60, by: 5)), id: \.self) { minute in
                    Text("\(minute) min").tag(minute)
                }
            }
            .pickerStyle(.wheel)
        }
        .frame(height: 120)
    }
}
