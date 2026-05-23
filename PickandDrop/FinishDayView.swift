import SwiftUI
import SwiftData

struct FinishDayView: View {
    let driver: DriverProfile
    
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    @Query var drivers: [DriverProfile]
    @Query var loads: [LoadItem]
    @Query var shifts: [Shift]
    @Query var companySettings: [CompanySettings]
    
    @State private var didFinish = false
    
    var settings: CompanySettings? {
        companySettings.first
    }
    
    var activeShift: Shift? {
        shifts.first(where: {
            $0.driverName == driver.name && $0.status == "active"
        })
    }
    
    var shiftLoads: [LoadItem] {

        return loads.filter {
            $0.driverName == driver.name &&
            !$0.isArchived &&
            (
                activeShift == nil ||
                $0.createdAt >= activeShift!.startedAt
            )
        }
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
                Text(
                    "\(settings?.dropoffCompanyName ?? "Dropoff") Tons: \(String(format: "%.2f", totalTons))"
                )
                
                if activeShift == nil {
                    Text("No active shift")
                        .foregroundStyle(.secondary)
                } else {
                    Button {
                        finishDay()
                    } label: {
                        VStack(spacing: 6) {
                            
                            Text("Finish Day")
                                .font(.largeTitle)
                                .bold()
                            
                            Text(
                                settings?.truckingCompanyName
                                ?? "Trucking Company"
                            )
                            .font(.headline)
                            .foregroundStyle(.blue)
                            
                            Text(
                                "\(settings?.pickupCompanyName ?? "Pickup") → \(settings?.dropoffCompanyName ?? "Dropoff")"
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        Button {
                            finishDay()
                        } label: {
                            Text("Finish Day")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                    }
                }
            }
            .padding()
            .navigationTitle(driver.name)
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

            let currentShift = activeShift

            let driverLoads = loads.filter {
                $0.driverName == driver.name &&
                !$0.isArchived &&
                (
                    currentShift == nil ||
                    $0.createdAt >= currentShift!.startedAt
                )
            }

            // ✅ FINAL export
            let _ = CSVExporter.generateCSV(
                loads: driverLoads,
                driver: driver,
                activeShift: shift,
                settings: settings,
                isFinal: true
            )

            // ✅ DELETE FINISHED LOCAL LOADS
            for load in driverLoads {
                load.isArchived = true
            }

            try context.save()

            // ✅ REMOVE ACTIVE FILE
            CSVExporter.deleteActiveCSV(driver: driver)

            didFinish = true

        } catch {
            print("❌ Failed to finish day:", error)
        }
    }
}
