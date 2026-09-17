import SwiftUI

struct FinishDayView: View {
    let driver: DriverProfile
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var supabaseLoads: [SupabaseLoad] = []
    @State private var supabaseSettings: SupabaseCompanySettings?
    @State private var supabaseDriver: SupabaseDriver?
    @State private var supabaseShifts: [SupabaseShift] = []
    
    @StateObject private var notificationManager = NotificationSyncManager()
    
    @State private var didFinish = false
    @State private var showMissingTicketsAlert = false
    @State private var showLoadList = false
    @State private var missingTicketCount = 0
    
    
    var settings: SupabaseCompanySettings? {
        supabaseSettings
    }
    
    var shiftLoads: [SupabaseLoad] {
        supabaseLoads.filter {
            $0.driver_name == driver.name &&
            ($0.is_archived ?? false) == false
        }
    }
    
    var activeShift: SupabaseShift? {
        supabaseShifts.first {
            $0.driver_name == driver.name &&
            $0.status == "active" &&
            isShiftToday($0)
        }
    }

    private func isShiftToday(
        _ shift: SupabaseShift
    ) -> Bool {

        guard let date =
            ISO8601DateFormatter().date(
                from: shift.started_at
            )
        else {
            return false
        }

        return Calendar.current.isDateInToday(date)
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
    
    var loadsMissingPickupTickets: [SupabaseLoad] {
        shiftLoads.filter {
            ($0.pickup_ticket_number ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty
        }
    }
    
    private var currentTruckNumber: String {
        supabaseDriver?.truck_number ?? driver.truckNumber
    }
    
    private var currentPickupName: String {
        activeShift?.pickup_location ?? "Pickup"
    }

    private var currentDropoffName: String {
        activeShift?.dropoff_location ?? "Dropoff"
    }
    
    private var tonBasedLoads: [SupabaseLoad] {
        shiftLoads.filter {
            ($0.billing_type ?? "per_ton") == "per_ton"
        }
    }

    private var perLoadLoads: [SupabaseLoad] {
        shiftLoads.filter {
            $0.billing_type == "per_load"
        }
    }

    private var finishDaySummaryText: String {

        if !perLoadLoads.isEmpty &&
           tonBasedLoads.isEmpty {

            return "\(currentDropoffName) Loads: \(perLoadLoads.count)"
        }

        let tons =
            tonBasedLoads.reduce(0.0) {
                $0 + ($1.delivery_tons ?? 0)
            }

        return String(
            format: "%@ Tons: %.2f",
            currentDropoffName,
            tons
        )
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                
                Text("Finish Day")
                    .font(.largeTitle)
                    .bold()

                Text("Loads: \(shiftLoads.count)")

                if currentDropoffName == "Chase" {

                    let deliveredLoads = shiftLoads.filter {
                        $0.status == "delivered" ||
                        $0.delivered_at != nil
                    }

                    Text("Chase Loads: \(deliveredLoads.count)")

                } else {

                    Text(
                        currentDropoffName +
                        " Tons: " +
                        String(format: "%.2f", totalTons)
                    )
                }

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
                                "\(currentPickupName) → \(currentDropoffName)"
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
        .alert("Missing Pickup Tickets",
               isPresented: $showMissingTicketsAlert) {
            
            Button("Edit Loads") {
                showLoadList = true
            }
            
            Button("Cancel", role: .cancel) { }
            
        } message: {
            
            Text(
                "\(missingTicketCount) load(s) are missing pickup ticket numbers. Tap Edit Loads to update them before finishing your day."
            )
        }
        .onAppear {
            Task {

                async let loadedLoads =
                    LoadSupabaseManager.shared.fetchLoads()

                async let loadedSettings =
                    CompanySupabaseManager.shared.fetchCompanySettings()

                async let loadedDrivers =
                    DriverSupabaseManager.shared.fetchDrivers()
                
                async let loadedShifts =
                    ShiftSupabaseManager.shared.fetchShifts()

                let newLoads = await loadedLoads
                let newSettings = await loadedSettings
                let cloudDrivers = await loadedDrivers
                let cloudShifts = await loadedShifts

                await MainActor.run {
                    supabaseLoads = newLoads
                    supabaseSettings = newSettings
                    supabaseShifts = cloudShifts

                    supabaseDriver = cloudDrivers.first {
                        $0.name == driver.name
                    }
                }
            }
        }
        .sheet(isPresented: $showLoadList, onDismiss: {
            Task {
                let loadedLoads =
                await LoadSupabaseManager.shared.fetchLoads()
                
                await MainActor.run {
                    supabaseLoads = loadedLoads
                }
            }
        }) {
            LoadListView(driver: driver)
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
            truckNumber: currentTruckNumber,
            message: message,
            loadTicket: nil
        )

        notificationManager.sendNotification(note)
    }
    
    func finishDay() async {

        guard activeShift != nil else {
            print("⚠️ No active Supabase shift for today")
            return
        }

        let driverLoads =
            await LoadSupabaseManager.shared.fetchLoads()
                .filter {
                    $0.driver_name == driver.name &&
                    ($0.is_archived ?? false) == false
                }
        
        let missingPickupTickets = driverLoads.filter {
            ($0.pickup_ticket_number ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty
        }
        
        if !missingPickupTickets.isEmpty {
            
            await MainActor.run {
                missingTicketCount =
                missingPickupTickets.count
                showMissingTicketsAlert = true
            }
            
            return
        }

        print("📦 FinishDay Supabase loads:", driverLoads.count)

        for load in driverLoads {

            if load.status == "delivered" ||
                load.delivered_at != nil {

                // await LoadSupabaseManager.shared.archiveLoad(
                //     loadID: load.id
                // )

                print(
                    "✅ Delivered load kept active:",
                    load.pickup_ticket_number ?? ""
                )
            } else {

                print("⏳ Keeping pending:",
                      load.pickup_ticket_number ?? "")
            }
        }

        let cloudFinished =
            await ShiftSupabaseManager.shared
                .finishActiveShift(
                    username: driver.username
                )

        if cloudFinished {

            print("☁️ Cloud shift closed")

        } else {

            print(
                "⚠️ Supabase shift failed to close"
            )

            // Don't finish the screen if the cloud
            // shift could not be closed.
            return
        }

        sendAdminNotification(
            type: "Finished Day",
            message:
                "\(driver.name) finished the day • \(driverLoads.count) loads"
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
    }
}
