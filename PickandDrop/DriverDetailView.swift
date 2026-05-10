import SwiftUI
import SwiftData

struct DriverDetailView: View {
    @State private var selectedLoad: LoadItem?
    @Query var companySettings: [CompanySettings]
    
    var settings: CompanySettings? {
        companySettings.first
    }

    let driver: DriverSummary
    let loads: [LoadItem]
    
    var grouped: [String: [LoadItem]] {
        [
            "\(settings?.pickupCompanyName ?? "Pickup") Loads": loads
        ]
    }
    
    var sortedCompanies: [String] {
        grouped.keys.sorted()
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [.blue.opacity(0.3), .black.opacity(0.2)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                List {
                    Section {
                        VStack(alignment: .leading) {
                            Text(
                                settings?.truckingCompanyName
                                ?? "Trucking Company"
                            )
                            .font(.caption.bold())
                            .foregroundStyle(.blue)
                            
                            Text(driver.name)
                                .font(.title.bold())
                            
                            if driver.isFinished {

                                Text("✅ Finished")
                                    .font(.caption)
                                    .foregroundStyle(.green)

                            } else {

                                Text("🟢 Active")
                                    .font(.caption)
                                    .foregroundStyle(.blue)
                            }
                            
                            Text("Truck \(driver.truck)")
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    ForEach(sortedCompanies, id: \.self) { company in
                        
                        if let loads = grouped[company] {
                            
                            let total = loads.reduce(0) { $0 + $1.pickupTons }
                            
                            Section(
                                header:
                                    VStack(alignment: .leading) {
                                        
                                        Text(company)
                                            .font(.headline)
                                        
                                        Text(
                                            "\(loads.count) loads • \(String(format: "%.0f", total)) tons"
                                        )
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    }
                            ) {
                                
                                ForEach(loads) { load in
                                    
                                    VStack(alignment: .leading) {
                                        
                                        HStack {
                                            
                                            Text(
                                                "\(settings?.pickupCompanyName ?? "Pickup") Ticket \(load.pickupTicketNumber)"
                                            )
                                            
                                            Spacer()
                                            
                                            Text(
                                                "\(load.pickupTons, specifier: "%.0f") \(settings?.pickupCompanyName ?? "Pickup") tons"
                                            )
                                            .foregroundStyle(.blue)
                                        }
                                        
                                        if load.isDelivered {
                                            
                                            Text(
                                                "\(settings?.dropoffCompanyName ?? "Dropoff") Ticket \(load.deliveryTicketNumber)"
                                            )
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        }
                                    }
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectedLoad = load
                                    }
                                }
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(driver.name)
            .sheet(item: $selectedLoad) { load in
                NavigationStack {
                    Form {
                        Section(settings?.pickupCompanyName ?? "Pickup") {
                            LabeledContent("Ticket", value: load.pickupTicketNumber)
                            LabeledContent("Tons", value: String(format: "%.2f", load.pickupTons))
                        }

                        Section(settings?.dropoffCompanyName ?? "Dropoff") {

                            if load.isDelivered {

                                LabeledContent(
                                    "\(settings?.dropoffCompanyName ?? "Dropoff") Ticket",
                                    value: load.deliveryTicketNumber
                                )

                                LabeledContent(
                                    "\(settings?.dropoffCompanyName ?? "Dropoff") Tons",
                                    value: String(format: "%.2f", load.deliveryTons)
                                )

                            } else {

                                LabeledContent(
                                    "Status",
                                    value: "Not delivered to \(settings?.dropoffCompanyName ?? "Dropoff") yet"
                                )
                            }
                        }
                        
                        Section("Driver") {
                            LabeledContent("Driver", value: load.driverName)
                        }
                    }
                    .navigationTitle("Load Details")
                }
            }
        }
    }
}

extension String {
    func trimmed() -> String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension String {
    func cleanedCSV() -> String {
        self
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
    }
}

