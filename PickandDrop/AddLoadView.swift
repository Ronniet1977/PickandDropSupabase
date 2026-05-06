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
            $0.driverName == driver.name &&
            $0.status.lowercased() == "active"
        })
    }
    
    var isValidLoad: Bool {
        let cleanTicket = pickupTicket.trimmingCharacters(in: .whitespacesAndNewlines)
        return !cleanTicket.isEmpty && Double(pickupTons) != nil
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
                    
                    if !pickupTons.isEmpty && Double(pickupTons) == nil {
                        Text("Enter a valid number for tons")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                
                Button("Save Load") {
                    saveLoad()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValidLoad || activeShift == nil)
            }
        }
        .navigationTitle("Add Load")
    }
    
    func saveLoad() {
        guard let tonsValue = Double(pickupTons) else { return }
        
        let cleanTicket = pickupTicket.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTicket.isEmpty else { return }
        
        let newLoad = LoadItem()
        newLoad.driverName = driver.name
        newLoad.pickupTicketNumber = cleanTicket   // ✅ ticket
        newLoad.pickupTons = tonsValue
        
        newLoad.status = "pickedUp"                // ✅ FIXED
        newLoad.createdAt = Date()
        newLoad.pickedUpAt = Date()               // ✅ timestamp
        
        if let shift = activeShift {
            newLoad.shift = shift
        }
        
        context.insert(newLoad)
        
        do {
            try context.save()
            dismiss()
        } catch {
            print("❌ Save failed:", error)
        }
    }
}
