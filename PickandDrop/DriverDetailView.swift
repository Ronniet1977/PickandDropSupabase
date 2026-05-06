import SwiftUI

struct DriverDetailView: View {
    @State private var selectedLoad: ReportLoadItem?
    
    let driver: DriverSummary
    let loads: [ReportLoadItem]
    
    var grouped: [String: [ReportLoadItem]] {
        Dictionary(grouping: loads, by: { $0.pickupCompany })
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
                            Text(driver.name)
                                .font(.title.bold())
                            Text("Truck \(driver.truck)")
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    ForEach(sortedCompanies, id: \.self) { company in
                        if let loads = grouped[company] {
                            
                            let total = loads.reduce(0) { $0 + $1.pickupTons }
                            
                            Section(header:
                                        VStack(alignment: .leading) {
                                Text(company)
                                    .font(.headline)
                                
                                Text("\(loads.count) loads • \(String(format: "%.0f", total)) tons")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            ) {
                                ForEach(loads) { load in
                                    VStack(alignment: .leading) {
                                        HStack {
                                            Text("Ticket \(load.pickupTicketNumber)")
                                            Spacer()
                                            Text("\(load.pickupTons, specifier: "%.0f") tons")
                                                .foregroundStyle(.blue)
                                        }
                                        
                                        if !load.deliveryTicketNumber.isEmpty {
                                            Text("HoneyGo Ticket \(load.deliveryTicketNumber)")
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
            .navigationTitle("Driver")
            .sheet(item: $selectedLoad) { load in
                NavigationStack {
                    Form {
                        Section("Pickup") {
                            LabeledContent("Company", value: load.pickupCompany)
                            LabeledContent("Ticket", value: load.pickupTicketNumber)
                            LabeledContent("Tons", value: String(format: "%.2f", load.pickupTons))
                        }
                        
                        Section("Delivery") {
                            LabeledContent("Company", value: load.deliveryCompany)
                            LabeledContent("Ticket", value: load.deliveryTicketNumber.isEmpty ? "Not delivered yet" : load.deliveryTicketNumber)
                            LabeledContent("Tons", value: String(format: "%.2f", load.deliveryTons))
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
