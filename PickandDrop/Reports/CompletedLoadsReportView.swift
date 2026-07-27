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
    @State private var settings: SupabaseCompanySettings?
    
    @State private var selectedYear =
    Calendar.current.component(.year, from: Date())
    
    @State private var selectedMonth = 0
    @State private var isLoading = true
    
    private let calendar = Calendar.current
    
    // MARK: - All completed loads
    
    var allCompletedLoads: [SupabaseLoad] {
        
        loads.filter {
            $0.status == "delivered" ||
            $0.delivered_at?.isEmpty == false
        }
    }
    
    // MARK: - Available years
    
    var years: [Int] {
        
        let foundYears = allCompletedLoads.compactMap { load -> Int? in
            
            guard let date = deliveredDate(for: load) else {
                return nil
            }
            
            return calendar.component(.year, from: date)
        }
        
        let uniqueYears = Array(Set(foundYears))
            .sorted(by: >)
        
        if uniqueYears.isEmpty {
            return [Calendar.current.component(.year, from: Date())]
        }
        
        return uniqueYears
    }
    
    // MARK: - Filtered loads
    
    var completedLoads: [SupabaseLoad] {
        
        allCompletedLoads
            .filter { load in
                
                guard let date = deliveredDate(for: load) else {
                    return false
                }
                
                let year =
                calendar.component(.year, from: date)
                
                let month =
                calendar.component(.month, from: date)
                
                let matchesYear =
                year == selectedYear
                
                let matchesMonth =
                selectedMonth == 0 ||
                month == selectedMonth
                
                return matchesYear && matchesMonth
            }
            .sorted {
                
                guard
                    let firstDate = deliveredDate(for: $0),
                    let secondDate = deliveredDate(for: $1)
                else {
                    return false
                }
                
                return firstDate > secondDate
            }
    }
    
    // MARK: - Totals
    
    var totalTons: Double {
        
        completedLoads.reduce(0) {
            $0 + ($1.pickup_tons ?? 0)
        }
    }
    
    var loadRevenue: Double {
        
        totalTons * (settings?.rate_per_ton ?? 0)
    }
    
    var fuelSurcharge: Double {
        
        totalTons *
        (settings?.fuel_surcharge_per_ton ?? 0)
    }
    
    var grandTotal: Double {
        
        loadRevenue + fuelSurcharge
    }
    
    var driverCount: Int {
        
        Set(
            completedLoads.compactMap {
                $0.driver_name
            }
        ).count
    }
    
    var archivedCount: Int {
        
        completedLoads.filter {
            $0.is_archived == true
        }.count
    }
    
    // MARK: - Driver totals
    
    var driverTotals: [(name: String, loads: Int, tons: Double)] {
        
        let grouped = Dictionary(
            grouping: completedLoads
        ) {
            $0.driver_name ?? "Unknown Driver"
        }
        
        return grouped.map { name, loads in
            
            let tons = loads.reduce(0.0) {
                $0 + ($1.pickup_tons ?? 0)
            }
            
            return (
                name: name,
                loads: loads.count,
                tons: tons
            )
        }
        .sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name)
            == .orderedAscending
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        
        List {
            
            Section("Report Period") {
                
                Picker(
                    "Year",
                    selection: $selectedYear
                ) {
                    
                    ForEach(years, id: \.self) { year in
                        Text(String(year))
                            .tag(year)
                    }
                }
                
                Picker(
                    "Month",
                    selection: $selectedMonth
                ) {
                    
                    Text("All Months")
                        .tag(0)
                    
                    ForEach(1...12, id: \.self) { month in
                        
                        Text(monthName(month))
                            .tag(month)
                    }
                }
            }
            
            Section("Summary") {
                
                HStack {
                    
                    summaryItem(
                        title: "Loads",
                        value: "\(completedLoads.count)"
                    )
                    
                    Spacer()
                    
                    summaryItem(
                        title: "Drivers",
                        value: "\(driverCount)"
                    )
                    
                    Spacer()
                    
                    summaryItem(
                        title: "Tons",
                        value: String(
                            format: "%.1f",
                            totalTons
                        )
                    )
                }
                
                HStack {
                    
                    Text("Archived Loads")
                    
                    Spacer()
                    
                    Text("\(archivedCount)")
                        .bold()
                }
            }
            
            Section("Revenue") {
                
                reportMoneyRow(
                    title: "Rate Per Ton",
                    amount: settings?.rate_per_ton ?? 0
                )
                
                reportMoneyRow(
                    title: "Load Revenue",
                    amount: loadRevenue
                )
                
                reportMoneyRow(
                    title: "Fuel Surcharge",
                    amount: fuelSurcharge
                )
                
                HStack {
                    
                    Text("Grand Total")
                        .font(.headline)
                    
                    Spacer()
                    
                    Text(
                        "$\(grandTotal, specifier: "%.2f")"
                    )
                    .font(.title3.bold())
                    .foregroundStyle(.green)
                }
            }
            
            Section("By Driver") {
                
                if driverTotals.isEmpty {
                    
                    Text("No driver totals available")
                        .foregroundStyle(.secondary)
                    
                } else {
                    
                    ForEach(driverTotals, id: \.name) { item in
                        
                        VStack(
                            alignment: .leading,
                            spacing: 6
                        ) {
                            
                            Text(item.name)
                                .font(.headline)
                            
                            HStack {
                                
                                Text(
                                    "\(item.loads) Load\(item.loads == 1 ? "" : "s")"
                                )
                                
                                Spacer()
                                
                                Text(
                                    "\(item.tons, specifier: "%.1f") Tons"
                                )
                                .bold()
                            }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 3)
                    }
                }
            }
            
            Section("Completed Loads") {
                
                if isLoading {
                    
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    
                } else if completedLoads.isEmpty {
                    
                    ContentUnavailableView(
                        "No Delivered Loads",
                        systemImage: "tray",
                        description: Text(
                            "No completed loads were found for the selected period."
                        )
                    )
                    
                } else {
                    
                    ForEach(
                        completedLoads,
                        id: \.id
                    ) { load in
                        
                        completedLoadRow(load)
                    }
                }
            }
        }
        .navigationTitle("Completed Loads")
        .task {
            await loadData()
        }
        .refreshable {
            await loadData()
        }
    }
    
    // MARK: - Load row
    
    @ViewBuilder
    func completedLoadRow(
        _ load: SupabaseLoad
    ) -> some View {
        
        VStack(
            alignment: .leading,
            spacing: 8
        ) {
            
            HStack {
                
                Text(
                    load.driver_name ??
                    "Unknown Driver"
                )
                .font(.headline)
                
                Spacer()
                
                if load.is_archived == true {
                    
                    Label(
                        "Archived",
                        systemImage: "archivebox.fill"
                    )
                    .font(.caption.bold())
                    .foregroundStyle(.purple)
                    
                } else {
                    
                    Label(
                        "Current",
                        systemImage: "checkmark.circle.fill"
                    )
                    .font(.caption.bold())
                    .foregroundStyle(.green)
                }
            }
            
            HStack {
                
                Text(
                    "Truck \(truckNumber(for: load))"
                )
                .font(.caption.bold())
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.blue.opacity(0.15))
                .foregroundStyle(.blue)
                .clipShape(Capsule())
                
                Spacer()
                
                Text(
                    "\(load.pickup_tons ?? 0, specifier: "%.1f") Tons"
                )
                .bold()
            }
            
            if let pickupTicket =
                load.pickup_ticket_number,
               !pickupTicket.isEmpty {
                
                Text(
                    "Pickup Ticket #\(pickupTicket)"
                )
                .font(.subheadline)
            }
            
            if let deliveryTicket =
                load.delivery_ticket_number,
               !deliveryTicket.isEmpty {
                
                Text(
                    "Delivery Ticket #\(deliveryTicket)"
                )
                .font(.subheadline)
            }
            
            Text(
                formatDate(load.delivered_at)
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Summary views
    
    @ViewBuilder
    func summaryItem(
        title: String,
        value: String
    ) -> some View {
        
        VStack(alignment: .leading) {
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text(value)
                .font(.title2.bold())
        }
    }
    
    @ViewBuilder
    func reportMoneyRow(
        title: String,
        amount: Double
    ) -> some View {
        
        HStack {
            
            Text(title)
            
            Spacer()
            
            Text(
                "$\(amount, specifier: "%.2f")"
            )
            .bold()
        }
    }
    
    // MARK: - Load data
    
    func loadData() async {
        
        await MainActor.run {
            isLoading = true
        }
        
        async let fetchedLoads =
        LoadSupabaseManager.shared.fetchLoads()
        
        async let fetchedDrivers =
        DriverSupabaseManager.shared.fetchDrivers()
        
        async let fetchedSettings =
        CompanySupabaseManager.shared.fetchCompanySettings()
        
        let loadedLoads = await fetchedLoads
        let loadedDrivers = await fetchedDrivers
        let loadedSettings = await fetchedSettings
        
        await MainActor.run {
            
            loads = loadedLoads
            drivers = loadedDrivers
            settings = loadedSettings
            
            if let firstYear = years.first {
                selectedYear = firstYear
            }
            
            isLoading = false
        }
    }
    
    // MARK: - Helpers
    
    func deliveredDate(
        for load: SupabaseLoad
    ) -> Date? {
        
        guard let text = load.delivered_at else {
            return nil
        }
        
        let fractionalFormatter =
        ISO8601DateFormatter()
        
        fractionalFormatter.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds
        ]
        
        if let date =
            fractionalFormatter.date(from: text) {
            
            return date
        }
        
        let standardFormatter =
        ISO8601DateFormatter()
        
        standardFormatter.formatOptions = [
            .withInternetDateTime
        ]
        
        return standardFormatter.date(from: text)
    }
    
    func truckNumber(
        for load: SupabaseLoad
    ) -> String {
        
        let loadDriverName =
        load.driver_name?
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .lowercased() ?? ""
        
        if let driver = drivers.first(where: {
            
            $0.name
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                .lowercased()
            == loadDriverName
            
        }) {
            return driver.truck_number
        }
        
        return load.truck_number ?? ""
    }
    
    func formatDate(
        _ dateString: String?
    ) -> String {
        
        guard
            let dateString,
            let date = deliveredDateString(dateString)
        else {
            return dateString ?? ""
        }
        
        return date.formatted(
            date: .abbreviated,
            time: .shortened
        )
    }
    
    func deliveredDateString(
        _ text: String
    ) -> Date? {
        
        let fractionalFormatter =
        ISO8601DateFormatter()
        
        fractionalFormatter.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds
        ]
        
        if let date =
            fractionalFormatter.date(from: text) {
            
            return date
        }
        
        return ISO8601DateFormatter()
            .date(from: text)
    }
    
    func monthName(
        _ month: Int
    ) -> String {
        
        let formatter = DateFormatter()
        
        return formatter.monthSymbols[
            month - 1
        ]
    }
}
