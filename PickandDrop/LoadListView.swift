import SwiftUI
import SwiftData

struct LoadListView: View {
    let driver: DriverProfile
    
    @Environment(\.modelContext) private var context
    @Query var loads: [LoadItem]
    
    var shiftLoads: [LoadItem] {
        loads
            .filter { $0.driverName == driver.name }
            .sorted { $0.createdAt > $1.createdAt }
    }
    
    var body: some View {
        List {
            if shiftLoads.isEmpty {
                Text("No loads yet")
                    .foregroundStyle(.secondary)
            }
            
            ForEach(shiftLoads) { load in
                VStack(alignment: .leading, spacing: 6) {
                    Text("Pickup: \(load.pickupCompany)")
                        .font(.headline)
                    
                    Text("BRC Ticket: \(load.pickupTicketNumber)")
                    
                    Text("Pickup Tons: \(String(format: "%.2f", load.pickupTons))")
                        .foregroundStyle(.secondary)
                    
                    if !load.deliveryTicketNumber.isEmpty {
                        Text("HoneyGo Ticket: \(load.deliveryTicketNumber)")
                    }
                    
                    if load.deliveryTons > 0 {
                        Text("Delivery Tons: \(String(format: "%.2f", load.deliveryTons))")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete(perform: deleteLoad)
        }
        .navigationTitle("Loads")
    }
    
    func deleteLoad(at offsets: IndexSet) {
        for index in offsets {
            context.delete(shiftLoads[index])
        }
        try? context.save()
    }
}
