import SwiftUI
import SwiftData

struct DriverDashboardView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hasSetup") var hasSetup = true
    @AppStorage("currentDriverName") var currentDriverName: String = ""
    
    @Query var drivers: [DriverProfile]
    @Query var shifts: [Shift]
    @Query var loads: [LoadItem]
    
    let driver: DriverProfile
    
    var activeShift: Shift? {
        shifts.first(where: {
            $0.driverName == driver.name && $0.status == "active"
        })
    }
    
    var shiftLoads: [LoadItem] {
        return loads.filter { $0.driverName == driver.name }
    }
    
    var totalTons: Double {
        shiftLoads.reduce(0.0) { $0 + $1.pickupTons }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Text(driver.name)
                    .font(.largeTitle)
                
                if let shift = activeShift,
                   shift.status != "finished" {

                    Text("🟢 Active")
                        .font(.caption)
                        .foregroundStyle(.blue)

                } else {

                    Text("✅ Finished")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
                
                Text("Truck \(driver.truckNumber)")
                    .font(.title3)
                
                if let shift = activeShift {
                    
                    VStack(spacing: 16) {
                        
                        Text("🟢 ACTIVE SHIFT")
                            .foregroundStyle(.green)
                        
                        HStack(spacing: 16) {
                            
                            StatCard(title: "Loads", value: "\(shiftLoads.count)")
                            
                            StatCard(title: "Tons", value: String(format: "%.2f", totalTons))
                            
                            StatCard(title: "Fuel", value: "$\(String(format: "%.2f", shift.fuelTotal))")
                        }
                        
                    }
                    
                } else {
                    
                    Text("⚪ No Active Shift")
                        .foregroundStyle(.secondary)
                }
                
                NavigationLink("Start Day") {
                    StartShiftView(driver: driver)
                }
                
                NavigationLink("Add Load") {
                    AddLoadView(driver: driver)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                
                NavigationLink("Pickup / Deliver") {
                    PickupDeliveryView(driver: driver)
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                
                NavigationLink("Today's Loads") {
                    LoadListView(driver: driver)
                }
                .buttonStyle(.borderedProminent)
                .tint(.gray)
                
                NavigationLink("Add Fuel") {
                    AddFuelView(driver: driver)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                
                NavigationLink("Finish Day") {
                    FinishDayView(driver: driver)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Log Out") {
                        logout()
                    }
                }
            }
        }
    }
    
    func logout() {
        hasSetup = false
        currentDriverName = ""
        print("Driver logged out")
    }
}

struct StatCard: View {
    
    let title: String
    let value: String
    
    var body: some View {
        
        VStack(spacing: 6) {
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text(value)
                .font(.headline)
                .bold()
            
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}
