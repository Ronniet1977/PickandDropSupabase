import SwiftUI
import SwiftData

struct StartShiftView: View {
    
    let driver: DriverProfile
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var settings: SupabaseCompanySettings?
    @State private var locations: [SupabaseLocation] = []
    @State private var supabaseShifts: [SupabaseShift] = []
    @State private var supabaseDriver: SupabaseDriver?
    
    @State private var selectedPickupLocation = ""
    @State private var selectedDropoffLocation = ""
    
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
            parseSupabaseDate(shift.started_at)
        else {
            return false
        }

        return Calendar.current.isDateInToday(date)
    }

    private func parseSupabaseDate(
        _ value: String
    ) -> Date? {

        let iso = ISO8601DateFormatter()

        if let date = iso.date(from: value) {
            return date
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)

        formatter.dateFormat =
            "yyyy-MM-dd HH:mm:ssXXXXX"

        if let date = formatter.date(from: value) {
            return date
        }

        formatter.dateFormat =
            "yyyy-MM-dd HH:mm:ss.SSSSSSXXXXX"

        return formatter.date(from: value)
    }
    
    var pickupLocations: [SupabaseLocation] {
        locations.filter {
            $0.location_type == "pickup" ||
            $0.location_type == "both"
        }
    }
    
    var dropoffLocations: [SupabaseLocation] {
        locations.filter {
            $0.location_type == "dropoff" ||
            $0.location_type == "both"
        }
    }
    
    private var currentTruckNumber: String {
        supabaseDriver?.truck_number
        ?? driver.truckNumber
    }
    
    var body: some View {

        ZStack {

            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.11, blue: 0.18),
                    Color(red: 0.15, green: 0.22, blue: 0.35),
                    Color.black.opacity(0.95)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {

                Spacer()

                VStack(spacing: 24) {

                    HStack(spacing: 10) {

                        Circle()
                            .fill(activeShift == nil ? .green : .orange)
                            .frame(width: 12, height: 12)

                        Text(activeShift == nil ? "READY TO START" : "SHIFT ACTIVE")
                            .font(.caption.weight(.bold))
                            .tracking(1.2)
                    }
                    .foregroundStyle(.white.opacity(0.85))

                    ZStack {

                        Circle()
                            .fill(.green.opacity(0.12))
                            .frame(width: 140, height: 140)

                        Circle()
                            .stroke(.green.opacity(0.25), lineWidth: 2)
                            .frame(width: 150, height: 150)

                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 72))
                            .foregroundStyle(.green)
                            .shadow(color: .green.opacity(0.5), radius: 20)
                    }

                    Text("Start Day")
                        .font(.system(size: 42, weight: .bold))

                    VStack(spacing: 6) {

                        Text(driver.name)
                            .font(.title2.weight(.semibold))

                        Text("Truck \(currentTruckNumber)")
                            .foregroundStyle(.white.opacity(0.7))
                        
                        Text(
                            settings?.trucking_company_name
                            ?? "Trucking Company"
                        )
                        .font(.caption.bold())
                        .foregroundStyle(.blue)

                        Text(
                            "\(selectedPickupLocation.isEmpty ? "Pickup" : selectedPickupLocation) → \(selectedDropoffLocation.isEmpty ? "Dropoff" : selectedDropoffLocation)"
                        )
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))

                        Text(Date(), style: .time)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.blue.opacity(0.9))
                    }
                }
                .foregroundStyle(.white)

                VStack(spacing: 20) {

                    if let shift = activeShift,
                       let startedAt =
                        parseSupabaseDate(shift.started_at) {

                        VStack(spacing: 14) {

                            Label(
                                "Shift Already Active",
                                systemImage: "checkmark.circle.fill"
                            )
                            .font(.headline)
                            .foregroundStyle(.green)

                            Text(
                                "Started " +
                                startedAt.formatted(
                                    date: .abbreviated,
                                    time: .shortened
                                )
                            )
                            .foregroundStyle(.white.opacity(0.7))

                            TimelineView(.periodic(from: .now, by: 1)) { context in

                                let elapsed =
                                    context.date.timeIntervalSince(
                                        startedAt
                                    )

                                let hours = Int(elapsed) / 3600
                                let minutes = (Int(elapsed) % 3600) / 60
                                let seconds = Int(elapsed) % 60

                                Text(
                                    String(
                                        format: "%02d:%02d:%02d",
                                        hours,
                                        minutes,
                                        seconds
                                    )
                                )
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(.green)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(28)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 30))

                    } else {
                        VStack(spacing: 16) {
                            
                            VStack(alignment: .leading, spacing: 6) {
                                
                                Text("Pickup")
                                    .font(.caption.bold())
                                    .foregroundStyle(.white.opacity(0.7))
                                
                                Picker(
                                    "Pickup",
                                    selection: $selectedPickupLocation
                                ) {
                                    ForEach(pickupLocations) { location in
                                        Text(location.name)
                                            .tag(location.name)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(.white.opacity(0.08))
                                .clipShape(
                                    RoundedRectangle(cornerRadius: 18)
                                )
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                
                                Text("Dropoff")
                                    .font(.caption.bold())
                                    .foregroundStyle(.white.opacity(0.7))
                                
                                Picker(
                                    "Dropoff",
                                    selection: $selectedDropoffLocation
                                ) {
                                    ForEach(dropoffLocations) { location in
                                        Text(location.name)
                                            .tag(location.name)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(.white.opacity(0.08))
                                .clipShape(
                                    RoundedRectangle(cornerRadius: 18)
                                )
                            }
                        }

                        Button {
                            Task {
                                await startShift()
                            }
                        } label: {
                            
                            HStack(spacing: 14) {
                                
                                Image(systemName: "play.fill")
                                
                                Text("Start Day")
                                    .fontWeight(.bold)
                            }
                            .font(.title3)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.green.gradient)
                            .clipShape(
                                RoundedRectangle(cornerRadius: 24)
                            )
                            .shadow(
                                color: .green.opacity(0.4),
                                radius: 14
                            )
                        }
                        .disabled(
                            selectedPickupLocation.isEmpty ||
                            selectedDropoffLocation.isEmpty
                        )
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task {
                
                let loadedSettings =
                    await CompanySupabaseManager.shared
                        .fetchCompanySettings()
                
                let loadedLocations =
                    await LocationSupabaseManager.shared
                        .fetchLocations()
                
                let loadedShifts =
                    await ShiftSupabaseManager.shared
                        .fetchShifts()
                
                let cloudDrivers =
                    await DriverSupabaseManager.shared
                        .fetchDrivers()
                
                await MainActor.run {
                    settings = loadedSettings
                    locations = loadedLocations
                    supabaseShifts = loadedShifts
                    supabaseDriver = cloudDrivers.first {
                        $0.name == driver.name
                    }
                    
                    if selectedPickupLocation.isEmpty {
                        selectedPickupLocation =
                        pickupLocations.first?.name
                        ?? loadedSettings?.pickup_company_name
                        ?? ""
                    }
                    
                    if selectedDropoffLocation.isEmpty {
                        selectedDropoffLocation =
                        dropoffLocations.first?.name
                        ?? loadedSettings?.dropoff_company_name
                        ?? ""
                    }
                }
            }
        }
    }
    
    func startShift() async {

        // Protect against accidentally starting
        // another active cloud shift.
        let currentShifts =
            await ShiftSupabaseManager.shared
                .fetchShifts()

        let alreadyActive =
            currentShifts.contains {
                $0.driver_name == driver.name &&
                $0.status == "active"
            }

        guard !alreadyActive else {

            await MainActor.run {
                supabaseShifts = currentShifts
            }

            print("⚠️ Driver already has an active Supabase shift")
            return
        }

        let cloudShift =
            await ShiftSupabaseManager.shared
                .startShift(
                    driverName: driver.name,
                    username: driver.username,
                    truckNumber: currentTruckNumber,
                    pickupLocation: selectedPickupLocation,
                    dropoffLocation: selectedDropoffLocation
                )

        guard let cloudShift else {

            print("❌ Supabase shift failed to start")
            return
        }

        print(
            "☁️ Cloud shift started:",
            cloudShift.id
        )

        await DriverSupabaseManager.shared
            .updateDutyStatus(
                username: driver.username,
                dutyStatus: "active"
            )

        UserDefaults.standard.set(
            false,
            forKey: "didCheckPendingDeliveries"
        )

        await MainActor.run {
            supabaseShifts = [cloudShift] + currentShifts
            dismiss()
        }

        print("✅ Shift started")
    }
}
