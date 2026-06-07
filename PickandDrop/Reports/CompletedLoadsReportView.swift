//
//  CompletedLoadsReportView.swift
//  PickandDrop
//
//  Created by Ronald Thayer Jr on 6/6/26.
//

import SwiftUI

struct CompletedLoadsReportView: View {

    @State private var loads: [SupabaseLoad] = []
    @State private var drivers: [SupabaseDriver] = []
    @State private var isLoading = true

    var completedLoads: [SupabaseLoad] {

        loads
            .filter {
                ($0.delivered_at?.isEmpty == false)
            }
            .sorted {
                ($0.delivered_at ?? "") >
                ($1.delivered_at ?? "")
            }
    }

    var totalTons: Double {

        completedLoads.reduce(0) {
            $0 + ($1.delivery_tons ?? 0)
        }
    }

    var driverCount: Int {

        Set(
            completedLoads.compactMap {
                $0.driver_name
            }
        ).count
    }

    var body: some View {

        List {

            Section {

                HStack {

                    VStack(alignment: .leading) {
                        Text("Loads")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("\(completedLoads.count)")
                            .font(.title2.bold())
                    }

                    Spacer()

                    VStack(alignment: .leading) {
                        Text("Drivers")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("\(driverCount)")
                            .font(.title2.bold())
                    }

                    Spacer()

                    VStack(alignment: .leading) {
                        Text("Tons")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("\(totalTons, specifier: "%.1f")")
                            .font(.title2.bold())
                    }
                }
            }

            if isLoading {

                ProgressView()

            } else if completedLoads.isEmpty {

                ContentUnavailableView(
                    "No Delivered Loads",
                    systemImage: "tray"
                )

            } else {

                ForEach(completedLoads, id: \.id) { load in

                    VStack(alignment: .leading, spacing: 8) {

                        HStack {

                            Text(
                                load.driver_name ??
                                "Unknown Driver"
                            )
                            .font(.headline)

                            Spacer()

                            Text("Truck \(truckNumber(for: load))")
                                .font(.caption.bold())
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(.blue.opacity(0.15))
                                .foregroundStyle(.blue)
                                .clipShape(Capsule())
                        }

                        if let ticket = load.delivery_ticket_number,
                           !ticket.isEmpty {

                            Text("Ticket # \(ticket)")
                                .font(.subheadline)
                        }

                        HStack {

                            Text(
                                "\(load.delivery_tons ?? 0, specifier: "%.1f") Tons"
                            )

                            Spacer()

                            Text(
                                load.delivered_at ?? ""
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Completed Loads")
        .task {
            await loadData()
        }
    }

    func loadData() async {

        isLoading = true

        async let fetchedLoads = LoadSupabaseManager.shared.fetchLoads()
        async let fetchedDrivers = DriverSupabaseManager.shared.fetchDrivers()

        loads = await fetchedLoads
        drivers = await fetchedDrivers

        isLoading = false
    }
    
    func truckNumber(for load: SupabaseLoad) -> String {

        let loadDriverName =
            load.driver_name?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased() ?? ""

        if let driver = drivers.first(where: {
            $0.name
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased() == loadDriverName
        }) {
            return driver.truck_number
        }

        return load.truck_number ?? ""
    }
    
    func formatDate(_ dateString: String?) -> String {

        guard let dateString else { return "" }

        let iso = ISO8601DateFormatter()

        guard let date = iso.date(from: dateString) else {
            return dateString
        }

        return date.formatted(
            date: .abbreviated,
            time: .shortened
        )
    }
}
