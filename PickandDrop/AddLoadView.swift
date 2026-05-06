import SwiftUI
import SwiftData

struct AddLoadView: View {
    let driver: DriverProfile
    
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    @Query var loads: [LoadItem]
    @Query var shifts: [Shift]
    
    @State private var company = ""
    @State private var ticket = ""
    @State private var tons = ""
    @State private var pickupTicket = ""
    @State private var pickupTons = ""
    
    var activeShift: Shift? {
        shifts.first(where: {
            $0.driverName == driver.name && $0.status == "active"
        })
    }
    
    var shiftLoads: [LoadItem] {
        loads.filter { $0.driverName == driver.name }
    }
    
    var body: some View {
        Form {
            if activeShift == nil {
                Section {
                    Text("No active shift. Start Day first.")
                        .foregroundStyle(.red)
                }
            } else {
                Section("Pickup (BRC)") {
                    TextField("BRC Ticket Number", text: $pickupTicket)
                    
                    TextField("BRC Tons", text: $pickupTons)
                        .keyboardType(.decimalPad)
                }
                
                Button("Save Load") {
                    saveLoad()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .navigationTitle("Add Load")
    }
    
    func saveLoad() {
        guard let tonsValue = Double(pickupTons) else {
            print("Invalid tons")
            return
        }
        
        let newLoad = LoadItem()
        newLoad.driverName = driver.name
        
        newLoad.pickupTicketNumber = pickupTicket
        newLoad.pickupTons = tonsValue
        newLoad.status = "new"
        
        context.insert(newLoad)
        
        do {
            try context.save()
            print("✅ Pickup created")
            
            dismiss()
            
        } catch {
            print("❌ Save failed:", error)
        }
    }
}

