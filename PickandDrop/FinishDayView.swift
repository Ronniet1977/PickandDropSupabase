import SwiftUI
import SwiftData

struct FinishDayView: View {
    let driver: DriverProfile
    
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    @Query var shifts: [Shift]

    @State private var supabaseLoads: [SupabaseLoad] = []
    @State private var supabaseSettings: SupabaseCompanySettings?
    
    
    @StateObject private var notificationManager = NotificationSyncManager()
    
    @State private var didFinish = false
    
    var settings: SupabaseCompanySettings? {
        supabaseSettings
    }
    
    var activeShift: Shift? {
        shifts.first(where: {
            $0.driverName == driver.name && $0.status == "active"
        })
    }
    
    var shiftLoads: [SupabaseLoad] {
        supabaseLoads.filter {
            $0.driver_name == driver.name &&
            ($0.is_archived ?? false) == false
        }
    }
    
    var totalTons: Double {
        shiftLoads
            .filter {
                $0.status == "delivered" ||
                $0.delivered_at != nil
            }
            .reduce(0.0) {
                $0 + ($1.delivery_tons ?? 0)
            }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                
                Text("Finish Day")
                    .font(.largeTitle)
                    .bold()
                
                Text("Loads: \(shiftLoads.count)")
                Text(
                    "\(settings?.dropoff_company_name ?? "Dropoff") Tons: \(String(format: "%.2f", totalTons))"
                )
                
                if activeShift == nil {
                    Text("No active shift")
                        .foregroundStyle(.secondary)
                } else {
                    Button {
                        Task {
                            await finishDay()
                        }
                    } label: {
                        VStack(spacing: 6) {
                            
                            Text("Finish Day")
                                .font(.largeTitle)
                                .bold()
                                .foregroundStyle(.red)
                            
                            Text(
                                settings?.trucking_company_name
                                ?? "Trucking Company"
                            )
                            .font(.headline)
                            .foregroundStyle(.blue)
                            
                            Text(
                                "\(settings?.pickup_company_name ?? "Pickup") → \(settings?.dropoff_company_name ?? "Dropoff")"
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
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
        .onAppear {
            Task {
                let loadedLoads =
                    await LoadSupabaseManager.shared.fetchLoads()

                let loadedSettings =
                    await CompanySupabaseManager.shared.fetchCompanySettings()

                await MainActor.run {
                    supabaseLoads = loadedLoads
                    supabaseSettings = loadedSettings
                }
            }
        }
    }
    
    func safeFileName(_ name: String) -> String {
        name
            .replacingOccurrences(of: "[^a-zA-Z0-9_-]", with: "_", options: .regularExpression)
            .replacingOccurrences(of: "_+", with: "_", options: .regularExpression)
    }
    
    func sendAdminNotification(
        type: String,
        message: String
    ) {
        let note = AppNotification(
            type: type,
            driverName: driver.name,
            truckNumber: driver.truckNumber,
            message: message,
            loadTicket: nil
        )

        notificationManager.sendNotification(note)
    }
    
    func finishDay() async {
        guard let shift = activeShift else { return }

        let driverLoads =
            await LoadSupabaseManager.shared.fetchLoads()
                .filter {
                    $0.driver_name == driver.name &&
                    ($0.is_archived ?? false) == false
                }

        print("📦 FinishDay Supabase loads:", driverLoads.count)

        for load in driverLoads {

            if load.status == "delivered" ||
                load.delivered_at != nil {

                // await LoadSupabaseManager.shared.archiveLoad(
                //     loadID: load.id
                // )

                print("🗂 Archived delivered:",
                      load.pickup_ticket_number ?? "")
            } else {

                print("⏳ Keeping pending:",
                      load.pickup_ticket_number ?? "")
            }
        }

        shift.status = "finished"
        shift.endedAt = Date()

        do {
            try context.save()

            sendAdminNotification(
                type: "Finished Day",
                message: "\(driver.name) finished the day • \(driverLoads.count) loads"
            )

            CSVExporter.deleteActiveCSV(driver: driver)
            
            await DriverSupabaseManager.shared
                .updateDutyStatus(
                    username: driver.username,
                    dutyStatus: "off_duty"
                )

            await MainActor.run {
                didFinish = true
            }

            print("✅ Shift finished")

        } catch {
            print("❌ Failed to finish day:", error)
        }
    }
}
