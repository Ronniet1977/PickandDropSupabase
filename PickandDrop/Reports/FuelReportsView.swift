//
//  FuelReportsView.swift
//  PickandDrop
//
//  Created by Ronald Thayer Jr on 6/5/26.
//

import SwiftUI

struct FuelReportsView: View {

    @State private var fuelEntries: [SupabaseFuel] = []
    @State private var selectedYear = Calendar.current.component(.year, from: Date())

    var years: [Int] {

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds
        ]

        let parsed = fuelEntries.compactMap { entry -> Int? in

            guard let text = entry.created_at,
                  let date = formatter.date(from: text)
            else { return nil }

            return Calendar.current.component(.year, from: date)
        }

        return Array(Set(parsed)).sorted(by: >)
    }

    var yearlyEntries: [SupabaseFuel] {

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds
        ]

        return fuelEntries.filter { entry in

            guard let text = entry.created_at,
                  let date = formatter.date(from: text)
            else { return false }

            return Calendar.current.component(
                .year,
                from: date
            ) == selectedYear
        }
    }

    var yearlyTotal: Double {
        yearlyEntries.reduce(0.0) {
            $0 + ($1.amount ?? 0)
        }
    }

    var body: some View {
        List {
            Section("Year") {
                Picker("Select Year", selection: $selectedYear) {
                    ForEach(years, id: \.self) { year in
                        Text(String(year)).tag(year)
                    }
                }
            }

            Section("Total") {
                Text("$\(yearlyTotal, specifier: "%.2f")")
                    .font(.title.bold())
            }

            Section("By Driver") {
                ForEach(driverTotals, id: \.name) { item in
                    HStack {
                        Text(item.name)
                        Spacer()
                        Text("$\(item.total, specifier: "%.2f")")
                    }
                }
            }
        }
        .navigationTitle("Fuel Reports")
        .onAppear {
            Task {
                fuelEntries =
                    await FuelSupabaseManager.shared.fetchFuel()
                
                print("Fuel entries:", fuelEntries.count)

                for fuel in fuelEntries {
                    print("DATE:", fuel.created_at ?? "nil")
                }

                if let firstYear = years.first {
                    selectedYear = firstYear
                }
            }
        }
    }

    var driverTotals: [(name: String, total: Double)] {
        let grouped = Dictionary(grouping: yearlyEntries) {
            $0.driver_name ?? "Unknown"
        }

        return grouped.map { name, entries in
            (
                name,
                entries.reduce(0.0) {
                    $0 + ($1.amount ?? 0)
                }
            )
        }
        .sorted { $0.name < $1.name }
    }
}
