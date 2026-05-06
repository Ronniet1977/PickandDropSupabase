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
            
            ForEach(shiftLoads, id: \.id) { load in
                VStack(alignment: .leading, spacing: 6) {
                    
                    Text("Ticket: \(load.pickupTicketNumber)")
                        .font(.headline)
                    
                    Text("Tons: \(String(format: "%.2f", load.pickupTons))")
                        .foregroundStyle(.secondary)
                    
                    if let picked = load.pickedUpAt {
                        Text("Picked up: \(picked.formatted(date: .omitted, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    
                    if let delivered = load.deliveredAt {
                        Text("Delivered: \(delivered.formatted(date: .omitted, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.green)
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
