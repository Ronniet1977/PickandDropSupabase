import SwiftUI
import SwiftData

struct FinishDayView: View {
    let driver: DriverProfile
    
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    @Query var drivers: [DriverProfile]
    @Query var loads: [LoadItem]
    @Query var shifts: [Shift]
    
    @State private var didFinish = false
    
    var combinedReports: [DriverSummary] {
        let grouped = Dictionary(grouping: loads) { $0.driverName }
        
        return grouped.map { (driverName, driverLoads) in
            
            let shift = shifts.first(where: {
                $0.driverName == driverName
            })
            
            let driverProfile =
            drivers.first(where: {
                $0.name == driverName
            })
            
            return DriverSummary(
                name: driverName,
                truck: driverProfile?.truckNumber ?? "Unknown",

                loads: driverLoads.count,

                pickupTons: driverLoads.reduce(0.0) {
                    $0 + $1.pickupTons
                },

                deliveryTons: driverLoads.reduce(0.0) {
                    $0 + $1.deliveryTons
                },

                fuel: shift?.fuelTotal ?? 0,
                status: shift?.status ?? "unknown"
            )
        }
    }

    var activeShift: Shift? {
        shifts.first(where: {
            $0.driverName == driver.name && $0.status == "active"
        })
    }
    
    var shiftLoads: [LoadItem] {
        return loads.filter { $0.driverName == driver.name }
    }
    
    var totalTons: Double {
        shiftLoads.reduce(0.0) { $0 + $1.deliveryTons }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                
                Text("Finish Day")
                    .font(.largeTitle)
                    .bold()
                
                Text("Loads: \(shiftLoads.count)")
                Text("Total Tons: \(String(format: "%.2f", totalTons))")
                
                if activeShift == nil {
                    Text("No active shift")
                        .foregroundStyle(.secondary)
                } else {
                    Button {
                        finishDay()
                    } label: {
                        Text("Finish Day")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
            }
            .padding()
            .navigationTitle("Finish Day")
        }
        
        // ✅ ATTACH HERE (outside NavigationStack block)
        .onChange(of: didFinish) {
            if didFinish {
                dismiss()
            }
        }
    }
    
    func safeFileName(_ name: String) -> String {
        name
            .replacingOccurrences(of: "[^a-zA-Z0-9_-]", with: "_", options: .regularExpression)
            .replacingOccurrences(of: "_+", with: "_", options: .regularExpression)
    }
    
    func finishDay() {
        guard let shift = activeShift else { return }
        
        shift.status = "finished"
        
        do {
            try context.save()
            print("✅ Shift finished")
            
            let driverLoads = loads.filter {
                $0.driverName == driver.name
            }
            
            DispatchQueue.global(qos: .background).async {
                // ✅ FINAL export
                let _ = CSVExporter.generateCSV(
                    loads: driverLoads,
                    driver: driver,
                    activeShift: shift,
                    isFinal: true
                )
                
                // ✅ RESET ACTIVE
                let _ = CSVExporter.generateCSV(
                    loads: [],
                    driver: driver,
                    activeShift: nil,
                    isFinal: false
                )
                
                // ✅ Back to main thread
                DispatchQueue.main.async {
                    didFinish = true   // 👈 triggers dismiss
                }
            }
            
        } catch {
            print("❌ Failed to finish day:", error)
        }
    }
    
    // 🔥 EXPORT
    func exportCombinedCSV() -> URL {
        var csv = "Driver,Truck,Loads,Pickup Tons,Delivery Tons\n"
        
        for d in combinedReports {
            csv += "\(escapeCSV(d.name)),\(escapeCSV(d.truck)),\(d.loads),\(String(format: "%.2f", d.pickupTons)),\(String(format: "%.2f", d.deliveryTons))\n"
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm"
        
        let fileName = "Admin-DriverReport-\(formatter.string(from: Date())).csv"
        
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsURL.appendingPathComponent(fileName)
        
        do {
            try csv.write(to: fileURL, atomically: true, encoding: .utf8)
            print("✅ Admin report saved:", fileURL)
        } catch {
            print("❌ Save failed:", error)
        }
        
        return fileURL
    }
    
    func escapeCSV(_ text: String) -> String {
        if text.contains(",") || text.contains("\"") || text.contains("\n") {
            return "\"\(text.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return text
    }
}
