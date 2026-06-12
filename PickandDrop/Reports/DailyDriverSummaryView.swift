//
//  DailyDriverSummaryView.swift
//  PickandDrop
//
//  Created by Ronald Thayer Jr on 6/6/26.
//

import SwiftUI

struct DailyDriverSummaryView: View {

    @State private var selectedDate = Date()
    @State private var loads: [SupabaseLoad] = []
    @State private var drivers: [SupabaseDriver] = []
    @State private var settings: SupabaseCompanySettings?
    @State private var isLoading = true
    @State private var selectedDriver: DriverSummary?
    
    var filteredLoads: [SupabaseLoad] {

        loads.filter { load in

            let dateString = load.picked_up_at ?? ""

            return dateString.prefix(10) ==
            selectedDate.formatted(.iso8601.year().month().day())
        }
    }

    var groupedDrivers: [DriverSummary] {

        let grouped = Dictionary(
            grouping: filteredLoads,
            by: { $0.driver_name ?? "Unknown" }
        )

        var summaries: [DriverSummary] = []

        for (driverName, driverLoads) in grouped {

            let pickupTons = driverLoads.reduce(0.0) {
                $0 + ($1.pickup_tons ?? 0)
            }

            let deliveryTons = driverLoads.reduce(0.0) {
                $0 + ($1.delivery_tons ?? 0)
            }

            let summary = DriverSummary(
                name: driverName,
                truck: driverLoads.first?.truck_number ?? "",
                loads: driverLoads.count,
                pickupTons: pickupTons,
                deliveryTons: deliveryTons,
                fuel: 0,
                status: "",
                isFinished: false
            )

            summaries.append(summary)
        }

        return summaries.sorted {
            $0.name < $1.name
        }
    }

    var body: some View {

        List {

            Section {

                DatePicker(
                    "Report Date",
                    selection: $selectedDate,
                    displayedComponents: .date
                )
            }

            if isLoading {

                ProgressView()

            } else if groupedDrivers.isEmpty {

                ContentUnavailableView(
                    "No Loads",
                    systemImage: "tray"
                )

            } else {

                ForEach(groupedDrivers) { driver in

                    VStack(alignment: .leading, spacing: 8) {

                        HStack {
                            Text(driver.name)
                                .font(.headline)

                            Spacer()

                            Text("Truck \(truckNumber(for: driver.name, fallback: driver.truck))")
                                .font(.caption.bold())
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(.blue.opacity(0.15))
                                .foregroundStyle(.blue)
                                .clipShape(Capsule())
                                .foregroundStyle(.secondary)
                        }

                        Divider()

                        HStack {

                            Label(
                                "\(driver.loads)",
                                systemImage: "shippingbox.fill"
                            )

                            Spacer()

                            Label(
                                "\(driver.deliveryTons, specifier: "%.1f") Tons",
                                systemImage: "scalemass.fill"
                            )
                        }
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedDriver = driver
                    }
                }
            }
        }
        .navigationTitle("Daily Summary")
        .sheet(item: $selectedDriver) { driver in
            NavigationStack {
                DriverDetailView(
                    driver: driver,
                    loads: filteredLoads.filter {
                        $0.driver_name == driver.name
                    },
                    settings: settings
                )
            }
        }
        .task {
            await loadData()
        }
    }

    func loadData() async {

        isLoading = true

        async let fetchedLoads = LoadSupabaseManager.shared.fetchLoads()
        async let fetchedDrivers = DriverSupabaseManager.shared.fetchDrivers()
        async let fetchedSettings =
        CompanySupabaseManager.shared.fetchCompanySettings()

        loads = await fetchedLoads
        drivers = await fetchedDrivers
        settings = await fetchedSettings

        isLoading = false
    }
    
    func truckNumber(for driverName: String, fallback: String) -> String {

        let cleanName =
            driverName
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()

        if let driver = drivers.first(where: {
            $0.name
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased() == cleanName
        }) {
            return driver.truck_number
        }

        return fallback
    }
}
