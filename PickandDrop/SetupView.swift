import SwiftUI
import SwiftData

struct SetupView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query var drivers: [DriverProfile]
    
    @AppStorage("hasSetup") private var hasSetup = false
    @AppStorage("currentDriverName") var currentDriverName: String = ""
    
    @State private var driverName = ""
    @State private var truckNumber = ""
    @State private var role = "driver"
    
    var body: some View {
        VStack(spacing: 24) {
            
            Text("Setup")
                .font(.largeTitle)
            
            TextField("Driver Name", text: $driverName)
                .textFieldStyle(.roundedBorder)
            
            TextField("Truck Number", text: $truckNumber)
                .textFieldStyle(.roundedBorder)
            
            Picker("Role", selection: $role) {
                Text("Driver").tag("driver")
                Text("Admin").tag("admin")
            }
            .pickerStyle(.segmented)
            
            Button("Save") {
                let driver = DriverProfile()
                driver.name = driverName
                driver.truckNumber = truckNumber
                driver.role = role

                currentDriverName = driver.name
                context.insert(driver)

                do {
                    try context.save()
                    print("✅ SAVE SUCCESS")
                    hasSetup = true
                } catch {
                    print("❌ SAVE FAILED:", error.localizedDescription)
                }
            }
        }
        .padding()
    }
}

