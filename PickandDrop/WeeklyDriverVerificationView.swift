//
//  WeeklyDriverVerificationView.swift
//  PickandDrop
//
//  Created by Ronald Thayer Jr on 9/17/26.
//

import SwiftUI

struct WeeklyDriverVerificationView: View {

    @State private var loads: [SupabaseLoad] = []
    @State private var isLoading = true

    @State private var startDate =
        Calendar.current.date(
            byAdding: .day,
            value: -6,
            to: Date()
        ) ?? Date()

    @State private var endDate = Date()

    private var filteredLoads: [SupabaseLoad] {

        let calendar = Calendar.current

        let start =
            calendar.startOfDay(for: startDate)

        let end =
            calendar.date(
                byAdding: .day,
                value: 1,
                to: calendar.startOfDay(for: endDate)
            ) ?? endDate

        return loads.filter { load in

            guard
                let dateText = load.created_at,
                let loadDate = parseSupabaseDate(dateText)
            else {
                return false
            }

            return loadDate >= start &&
                   loadDate < end
        }
    }

    private var driverNames: [String] {

        Array(
            Set(
                filteredLoads.compactMap {
                    $0.driver_name
                }
            )
        )
        .sorted()
    }
    
    private var weekTonLoads: [SupabaseLoad] {
        filteredLoads.filter {
            ($0.billing_type ?? "per_ton") == "per_ton"
        }
    }

    private var weekPerLoadLoads: [SupabaseLoad] {
        filteredLoads.filter {
            $0.billing_type == "per_load"
        }
    }

    private var weekPickupTons: Double {
        weekTonLoads.reduce(0.0) {
            $0 + ($1.pickup_tons ?? 0)
        }
    }

    private var weekDeliveryTons: Double {
        weekTonLoads.reduce(0.0) {
            $0 + ($1.delivery_tons ?? 0)
        }
    }

    var body: some View {

        ScrollView {

            VStack(spacing: 20) {

                VStack(alignment: .leading, spacing: 16) {

                    Text("Weekly Driver Verification")
                        .font(.largeTitle.bold())

                    Text("Verify driver loads and tons before invoicing.")
                        .foregroundStyle(.secondary)

                    HStack(spacing: 20) {

                        DatePicker(
                            "From",
                            selection: $startDate,
                            displayedComponents: .date
                        )

                        DatePicker(
                            "To",
                            selection: $endDate,
                            in: startDate...,
                            displayedComponents: .date
                        )
                    }
                }
                .padding()

                HStack {

                    VStack(alignment: .leading) {
                        Text("Drivers")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("\(driverNames.count)")
                            .font(.title2.bold())
                    }

                    Spacer()

                    VStack(alignment: .trailing) {
                        Text("Total Loads")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("\(filteredLoads.count)")
                            .font(.title2.bold())
                    }
                }
                .padding()
                .background(.thinMaterial)
                .clipShape(
                    RoundedRectangle(cornerRadius: 20)
                )

                if isLoading {

                    ProgressView("Loading loads...")

                } else if driverNames.isEmpty {

                    ContentUnavailableView(
                        "No Loads",
                        systemImage: "shippingbox",
                        description: Text(
                            "No loads were found for the selected dates."
                        )
                    )

                } else {

                    ForEach(driverNames, id: \.self) { driverName in

                        let driverLoads =
                            filteredLoads.filter {
                                $0.driver_name == driverName
                            }
                        
                        let routeGroups =
                            Dictionary(grouping: driverLoads) { load in
                                "\(load.pickup_location ?? "Pickup") → \(load.dropoff_location ?? "Dropoff")"
                            }

                        let tonLoads =
                            driverLoads.filter {
                                ($0.billing_type ?? "per_ton")
                                    == "per_ton"
                            }

                        let perLoadLoads =
                            driverLoads.filter {
                                $0.billing_type == "per_load"
                            }

                        let pickupTons =
                            tonLoads.reduce(0.0) {
                                $0 + ($1.pickup_tons ?? 0)
                            }

                        let deliveryTons =
                            tonLoads.reduce(0.0) {
                                $0 + ($1.delivery_tons ?? 0)
                            }

                        VStack(alignment: .leading, spacing: 14) {

                            HStack {

                                Text(driverName)
                                    .font(.headline)

                                Spacer()

                                Text("\(driverLoads.count) Loads")
                                    .font(.headline)
                            }

                            Divider()

                            if !tonLoads.isEmpty {

                                HStack {

                                    verificationStat(
                                        "Pickup Tons",
                                        value: String(
                                            format: "%.0f",
                                            pickupTons
                                        )
                                    )

                                    Spacer()

                                    verificationStat(
                                        "Delivery Tons",
                                        value: String(
                                            format: "%.0f",
                                            deliveryTons
                                        )
                                    )

                                    Spacer()

                                    verificationStat(
                                        "Difference",
                                        value: String(
                                            format: "%.0f",
                                            pickupTons - deliveryTons
                                        )
                                    )
                                }
                            }

                            if !perLoadLoads.isEmpty {

                                HStack {

                                    Image(
                                        systemName:
                                            "shippingbox.fill"
                                    )

                                    Text(
                                        "\(perLoadLoads.count) Per-Load"
                                    )
                                    .fontWeight(.semibold)
                                }
                                .foregroundStyle(.secondary)
                            }
                            
                            Divider()

                            Text("Route Breakdown")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)

                            ForEach(
                                routeGroups.keys.sorted(),
                                id: \.self
                            ) { routeName in

                                let routeLoads =
                                    routeGroups[routeName] ?? []

                                let routeTonLoads =
                                    routeLoads.filter {
                                        ($0.billing_type ?? "per_ton") == "per_ton"
                                    }

                                let routePerLoadLoads =
                                    routeLoads.filter {
                                        $0.billing_type == "per_load"
                                    }

                                let routePickupTons =
                                    routeTonLoads.reduce(0.0) {
                                        $0 + ($1.pickup_tons ?? 0)
                                    }

                                let routeDeliveryTons =
                                    routeTonLoads.reduce(0.0) {
                                        $0 + ($1.delivery_tons ?? 0)
                                    }

                                VStack(alignment: .leading, spacing: 8) {

                                    HStack {

                                        Label(
                                            routeName,
                                            systemImage: "arrow.left.arrow.right"
                                        )
                                        .font(.subheadline.bold())

                                        Spacer()

                                        Text("\(routeLoads.count) Loads")
                                            .font(.subheadline.bold())
                                    }

                                    if !routeTonLoads.isEmpty {

                                        HStack {

                                            verificationStat(
                                                "Pickup",
                                                value: String(
                                                    format: "%.2f",
                                                    routePickupTons
                                                )
                                            )

                                            Spacer()

                                            verificationStat(
                                                "Delivery",
                                                value: String(
                                                    format: "%.2f",
                                                    routeDeliveryTons
                                                )
                                            )

                                            Spacer()

                                            verificationStat(
                                                "Difference",
                                                value: String(
                                                    format: "%.2f",
                                                    routePickupTons - routeDeliveryTons
                                                )
                                            )
                                        }
                                    }

                                    if !routePerLoadLoads.isEmpty {

                                        Label(
                                            "\(routePerLoadLoads.count) Per-Load",
                                            systemImage: "shippingbox.fill"
                                        )
                                        .font(.caption.bold())
                                        .foregroundStyle(.secondary)
                                    }
                                }
                                .padding()
                                .background(.secondary.opacity(0.08))
                                .clipShape(
                                    RoundedRectangle(cornerRadius: 14)
                                )
                            }
                        }
                        .padding()
                        .background(.thinMaterial)
                        .clipShape(
                            RoundedRectangle(cornerRadius: 20)
                        )
                    }
                    
                    VStack(alignment: .leading, spacing: 16) {

                        Text("Week Totals")
                            .font(.title2.bold())

                        Divider()

                        HStack {

                            verificationStat(
                                "Total Loads",
                                value: "\(filteredLoads.count)"
                            )

                            Spacer()

                            verificationStat(
                                "Per-Ton Loads",
                                value: "\(weekTonLoads.count)"
                            )

                            Spacer()

                            verificationStat(
                                "Per-Load Loads",
                                value: "\(weekPerLoadLoads.count)"
                            )
                        }

                        Divider()

                        HStack {

                            verificationStat(
                                "Pickup Tons",
                                value: String(
                                    format: "%.2f",
                                    weekPickupTons
                                )
                            )

                            Spacer()

                            verificationStat(
                                "Delivery Tons",
                                value: String(
                                    format: "%.2f",
                                    weekDeliveryTons
                                )
                            )

                            Spacer()

                            verificationStat(
                                "Difference",
                                value: String(
                                    format: "%.2f",
                                    weekPickupTons - weekDeliveryTons
                                )
                            )
                        }
                    }
                    .padding()
                    .background(.thinMaterial)
                    .clipShape(
                        RoundedRectangle(cornerRadius: 20)
                    )
                }
            }
            .padding()
        }
        .navigationTitle("Driver Verification")
        .task {

            loads =
                await LoadSupabaseManager.shared
                    .fetchLoads()

            isLoading = false
        }
    }

    @ViewBuilder
    private func verificationStat(
        _ title: String,
        value: String
    ) -> some View {

        VStack(alignment: .leading, spacing: 4) {

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.headline)
        }
    }

    private func parseSupabaseDate(
        _ text: String
    ) -> Date? {

        let formatter =
            ISO8601DateFormatter()

        formatter.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds
        ]

        if let date = formatter.date(from: text) {
            return date
        }

        formatter.formatOptions = [
            .withInternetDateTime
        ]

        return formatter.date(from: text)
    }
}
