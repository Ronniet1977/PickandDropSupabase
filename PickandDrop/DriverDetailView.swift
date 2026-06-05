import SwiftUI
import SwiftData

struct DriverDetailView: View {

    @State private var selectedLoad: SupabaseLoad?

    let driver: DriverSummary
    let loads: [SupabaseLoad]
    let settings: SupabaseCompanySettings?
    
    var grouped: [String: [SupabaseLoad]] {
        [
            "\(settings?.pickup_company_name ?? "Pickup") Loads": loads
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
                                settings?.trucking_company_name
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
                            
                            let total = loads.reduce(0.0) {
                                $0 + ($1.pickup_tons ?? 0)
                            }
                            
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
                                    
                                    VStack(alignment: .leading, spacing: 8) {

                                        HStack {

                                            Text(
                                                "\(settings?.pickup_company_name ?? "Pickup") Ticket \(load.pickup_ticket_number ?? "")"
                                            )

                                            Spacer()

                                            Text(
                                                "\(load.pickup_tons ?? 0, specifier: "%.0f") Tons"
                                            )
                                            .foregroundStyle(.blue)
                                            .fontWeight(.semibold)
                                        }

                                        if load.status == "delivered" {

                                            HStack {

                                                Text(
                                                    "\(settings?.dropoff_company_name ?? "Dropoff") Ticket \(load.delivery_ticket_number ?? "")"
                                                )

                                                Spacer()

                                                Text(
                                                    "\(load.delivery_tons ?? 0, specifier: "%.0f") Tons"
                                                )
                                                .foregroundStyle(.green)
                                                .fontWeight(.semibold)
                                            }
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
                        Section(settings?.pickup_company_name ?? "Pickup") {
                            LabeledContent("Ticket", value: load.pickup_ticket_number ?? "")
                            LabeledContent("Tons", value: String(format: "%.2f", load.pickup_tons ?? 0))
                        }

                        Section(settings?.dropoff_company_name ?? "Dropoff") {

                            if load.status == "delivered" {

                                LabeledContent(
                                    "\(settings?.dropoff_company_name ?? "Dropoff") Ticket",
                                    value: load.delivery_ticket_number ?? ""
                                )

                                LabeledContent(
                                    "\(settings?.dropoff_company_name ?? "Dropoff") Tons",
                                    value: String(format: "%.2f", load.delivery_tons ?? 0)
                                )

                            } else {

                                LabeledContent(
                                    "Status",
                                    value: "Not delivered to \(settings?.dropoff_company_name ?? "Dropoff") yet"
                                )
                            }
                        }
                        
                        Section("Driver") {
                            LabeledContent(
                                "Driver",
                                value: load.driver_name ?? ""
                            )
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

