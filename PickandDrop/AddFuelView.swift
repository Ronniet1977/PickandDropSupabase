import SwiftUI
import SwiftData

struct AddFuelView: View {
    let driver: DriverProfile
    
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query var shifts: [Shift]
    @Query var loads: [LoadItem]
    
    @State private var fuelAmount = ""
    
    var activeShift: Shift? {
        shifts.first(where: {
            $0.driverName == driver.name && $0.status == "active"
        })
    }
    
    var body: some View {
        Form {
            if activeShift == nil {
                Text("No active shift. Start Day first.")
                    .foregroundStyle(.red)
            } else {
                Section("Fuel") {
                    TextField("Fuel total $", text: $fuelAmount)
                        .keyboardType(.decimalPad)
                }
                
                Button("Save Fuel") {
                    saveFuel()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .navigationTitle("Add Fuel")
    }
    
    func saveFuel() {
        guard let shift = activeShift else { return }
        
        let amount = Double(fuelAmount) ?? 0
        shift.fuelTotal += amount
        
        do {
            try context.save()
            print("✅ Fuel saved")
            
            let driverLoads = loads.filter { $0.driverName == driver.name }
            let currentShift = shift
            
            DispatchQueue.global(qos: .background).async {
                _ = CSVExporter.generateCSV(
                    loads: driverLoads,
                    driver: driver,
                    activeShift: currentShift
                )
            }
            
            dismiss()
            
        } catch {
            print("❌ Fuel save failed:", error)
        }
    }
}

