import SwiftUI
import SwiftData

struct StartShiftView: View {
    
    let driver: DriverProfile
    
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query var shifts: [Shift]
    @Query var loads: [LoadItem]
    
    var activeShift: Shift? {
        shifts.first(where: {
            $0.driverName == driver.name && $0.status == "active"
        })
    }
    
    var body: some View {
        
        VStack(spacing: 24) {
            
            Text("Start Day")
                .font(.largeTitle)
                .bold()
            
            if let shift = activeShift {
                
                Text("🟢 Shift Already Active")
                    .foregroundStyle(.green)
                
                Text("Started: \(shift.startedAt.formatted())")
                
            } else {
                
                Button("Start Shift") {
                    startShift()
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
        }
        .padding()
    }
    
    func startShift() {
        let newShift = Shift()
        newShift.driverName = driver.name

        context.insert(newShift)

        do {
            try context.save()
            print("✅ Shift started")

            let driverLoads = loads.filter {
                $0.driverName == driver.name
            }

            let currentShift = newShift

            _ = CSVExporter.generateCSV(
                loads: driverLoads,
                driver: driver,
                activeShift: currentShift
            )

            dismiss()

        } catch {
            print("❌ Failed to start shift:", error)
        }
    }
}
