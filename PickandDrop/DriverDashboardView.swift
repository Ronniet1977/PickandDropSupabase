import SwiftUI
import SwiftData

struct DriverDashboardView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hasSetup") var hasSetup = true
    @AppStorage("currentDriverName") var currentDriverName: String = ""
    @AppStorage("isLoggedIn")
    var isLoggedIn = false

    @AppStorage("mustChangePassword")
    var mustChangePassword = false
    
    @AppStorage("didCheckPendingDeliveries")
    var didCheckPendingDeliveries = false
    
    @Query var drivers: [DriverProfile]
    @Query var shifts: [Shift]
    @Query var loads: [LoadItem]

    @State private var supabaseSettings: SupabaseCompanySettings?
    @State private var supabaseLoads: [SupabaseLoad] = []
    @State private var supabaseShifts: [SupabaseShift] = []
    @State private var supabaseDriver: SupabaseDriver?
    
    @State private var showPendingDeliveryAlert = false
    @State private var showPickupDeliveryView = false
    @State private var showOldShiftAlert = false
    @State private var showStartDayRequired = false
    
    
    let driver: DriverProfile
    
    var settings: SupabaseCompanySettings? {
        supabaseSettings
    }
    
    var currentPickupName: String {

        if let shiftLocation =
            activeShift?.pickup_location?
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                ),
           !shiftLocation.isEmpty {

            return shiftLocation
        }

        return settings?.pickup_company_name
            ?? "Pickup"
    }
    
    var currentDropoffName: String {

        if let shiftLocation =
            activeShift?.dropoff_location?
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                ),
           !shiftLocation.isEmpty {

            return shiftLocation
        }

        return settings?.dropoff_company_name
            ?? "Dropoff"
    }
    
    var pendingDeliveries: [SupabaseLoad] {
        supabaseLoads.filter { load in

            guard
                load.driver_name == driver.name,
                load.is_archived != true,
                load.delivered_at == nil,
                let pickedString = load.picked_up_at,
                let pickedDate = parseSupabaseDate(pickedString),
                let startedString = activeShift?.started_at,
                let shiftStart = parseSupabaseDate(startedString)
            else {
                return false
            }

            return pickedDate < shiftStart
        }
    }
    
    var oldActiveShift: SupabaseShift? {
        supabaseShifts.first {
            guard
                $0.driver_name == driver.name,
                $0.status == "active",
                let date = parseSupabaseDate($0.started_at)
            else {
                return false
            }

            return !Calendar.current.isDateInToday(date)
        }
    }

    var hasOldActiveShift: Bool {
        oldActiveShift != nil
    }

    var shiftLoads: [SupabaseLoad] {
        supabaseLoads.filter {
            $0.driver_name == driver.name &&
            ($0.is_archived ?? false) == false
        }
    }

    var totalTons: Double {
        shiftLoads.reduce(0.0) {
            $0 + ($1.pickup_tons ?? 0)
        }
    }

    var todayLoads: [SupabaseLoad] {
        shiftLoads
    }
    
    var activeShift: SupabaseShift? {
        supabaseShifts.first {
            $0.driver_name == driver.name &&
            $0.status == "active" &&
            isShiftToday($0)
        }
    }
    
    private var currentTruckNumber: String {
        supabaseDriver?.truck_number
        ?? driver.truckNumber
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
    
    var hasActiveShift: Bool {
        activeShift != nil
    }
    
    var activeShiftDuration: String {

        guard let shift = activeShift else {
            return "OFF DUTY"
        }

        guard let startedAt =
            parseSupabaseDate(shift.started_at)
        else {
            return "OFF DUTY"
        }

        let seconds =
            Int(Date().timeIntervalSince(startedAt))

        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60

        return "\(hours)h \(minutes)m"
    }
    
    var body: some View {

        NavigationStack {

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

                ScrollView {

                    VStack(spacing: 24) {

                        // TOP DASHBOARD CARD

                        VStack(alignment: .leading, spacing: 16) {

                            HStack {

                                VStack(alignment: .leading, spacing: 6) {

                                    HStack(spacing: 8) {

                                        Circle()
                                            .fill(hasActiveShift ? .green : .gray)
                                            .frame(width: 12, height: 12)

                                        Text(hasActiveShift ? "ON DUTY" : "OFF DUTY")
                                            .font(.caption.bold())
                                            .foregroundStyle(
                                                hasActiveShift ? .green : .secondary
                                            )
                                    }

                                    Text(
                                        settings?.trucking_company_name
                                        ?? "Trucking Company"
                                    )
                                    .font(.caption.bold())
                                    .foregroundStyle(.blue)

                                    Text(driver.name)
                                        .font(.largeTitle.bold())
                                        .foregroundStyle(.white)

                                    Text("Truck \(currentTruckNumber)")
                                        .foregroundStyle(.white.opacity(0.7))
                                    
                                    Text(
                                        "\(currentPickupName) → \(currentDropoffName)"
                                    )
                                    .font(.caption.bold())
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(.blue.opacity(0.15))
                                    .foregroundStyle(.blue)
                                    .clipShape(Capsule())

                                    TimelineView(.periodic(from: .now, by: 1)) { context in

                                        Text(
                                            context.date.formatted(
                                                date: .omitted,
                                                time: .standard
                                            )
                                        )
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.white.opacity(0.7))
                                    }

                                    if let shift = activeShift,
                                       let startedAt =
                                        parseSupabaseDate(shift.started_at) {

                                        TimelineView(.periodic(from: .now, by: 60)) { context in

                                            let seconds = Int(
                                                context.date.timeIntervalSince(
                                                    startedAt
                                                )
                                            )

                                            let hours = seconds / 3600
                                            let minutes = (seconds % 3600) / 60

                                            Text("Shift: \(hours)h \(minutes)m")
                                                .font(.caption.bold())
                                                .foregroundStyle(.blue)
                                        }
                                    }
                                }

                                Spacer()

                                ZStack {

                                    Circle()
                                        .fill(.blue.opacity(0.15))
                                        .frame(width: 72, height: 72)

                                    Text(driver.name.prefix(1))
                                        .font(.largeTitle.bold())
                                        .foregroundStyle(.blue)
                                }
                            }

                            Divider()

                            let tonLoads = todayLoads.filter {
                                ($0.billing_type ?? "per_ton") == "per_ton"
                            }

                            let perLoadLoads = todayLoads.filter {
                                $0.billing_type == "per_load"
                            }

                            let deliveredPerLoad = perLoadLoads.filter {
                                $0.status == "delivered" ||
                                $0.delivered_at != nil
                            }

                            let pendingPerLoad =
                                perLoadLoads.count - deliveredPerLoad.count

                            if !tonLoads.isEmpty &&
                               !perLoadLoads.isEmpty {

                                // MIXED DAY

                                VStack(spacing: 14) {

                                    HStack {

                                        dashboardStat(
                                            title: "Loads",
                                            value: "\(todayLoads.count)"
                                        )

                                        Spacer()

                                        let pickupTons = tonLoads.reduce(0.0) {
                                            $0 + ($1.pickup_tons ?? 0)
                                        }

                                        dashboardStat(
                                            title: "\(currentPickupName) Tons",
                                            value: String(
                                                format: "%.0f",
                                                pickupTons
                                            )
                                        )

                                        Spacer()

                                        dashboardStat(
                                            title: "Per-Load",
                                            value: "\(perLoadLoads.count)"
                                        )
                                    }

                                    HStack {

                                        dashboardStat(
                                            title: "Delivered",
                                            value: "\(deliveredPerLoad.count)"
                                        )

                                        Spacer()

                                        dashboardStat(
                                            title: "Pending",
                                            value: "\(pendingPerLoad)"
                                        )
                                    }
                                }

                            } else if !perLoadLoads.isEmpty {

                                // CHASE / PER-LOAD DAY

                                HStack {

                                    dashboardStat(
                                        title: "Loads",
                                        value: "\(perLoadLoads.count)"
                                    )

                                    Spacer()

                                    dashboardStat(
                                        title: "Delivered",
                                        value: "\(deliveredPerLoad.count)"
                                    )

                                    Spacer()

                                    dashboardStat(
                                        title: "Pending",
                                        value: "\(pendingPerLoad)"
                                    )
                                }

                            } else {

                                // HONEYGO / PER-TON DAY

                                let pickupTons = tonLoads.reduce(0.0) {
                                    $0 + ($1.pickup_tons ?? 0)
                                }

                                let deliveryTons = tonLoads.reduce(0.0) {
                                    $0 + ($1.delivery_tons ?? 0)
                                }

                                HStack {

                                    dashboardStat(
                                        title: "Loads",
                                        value: "\(tonLoads.count)"
                                    )

                                    Spacer()

                                    dashboardStat(
                                        title: "\(currentPickupName) Tons",
                                        value: String(
                                            format: "%.0f",
                                            pickupTons
                                        )
                                    )

                                    Spacer()

                                    dashboardStat(
                                        title: "\(currentDropoffName) Tons",
                                        value: String(
                                            format: "%.0f",
                                            deliveryTons
                                        )
                                    )
                                }
                            }
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 28))
                        .padding(.horizontal)

                        // ACTION GRID

                        LazyVGrid(
                            columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ],
                            spacing: 16
                        ) {

                            if !hasActiveShift {

                                NavigationLink {
                                    StartShiftView(driver: driver)
                                } label: {

                                    ActionCard(
                                        title: "Start Day",
                                        icon: "play.circle.fill",
                                        color: .green
                                    )
                                }
                            }

                            if activeShift != nil {

                                NavigationLink {
                                    AddLoadView(driver: driver)
                                } label: {

                                    ActionCard(
                                        title: "Add Load",
                                        icon: "plus.circle.fill",
                                        color: .blue
                                    )
                                }

                            } else {

                                Button {
                                    showStartDayRequired = true
                                } label: {

                                    ActionCard(
                                        title: "Add Load",
                                        icon: "plus.circle.fill",
                                        color: .blue
                                    )
                                }
                                .buttonStyle(.plain)
                            }

                            NavigationLink {
                                PickupDeliveryView(driver: driver)
                            } label: {

                                ActionCard(
                                    title: "Pickup / Deliver",
                                    icon: "truck.box.fill",
                                    color: .purple
                                )
                            }

                            NavigationLink {
                                LoadListView(driver: driver)
                            } label: {

                                ActionCard(
                                    title: "Today's Loads",
                                    icon: "list.bullet.rectangle",
                                    color: .gray
                                )
                            }

                            NavigationLink {
                                AddFuelView(driver: driver)
                            } label: {

                                ActionCard(
                                    title: "Add Fuel",
                                    icon: "fuelpump.fill",
                                    color: .orange
                                )
                            }
                        }
                        .padding(.horizontal)

                        if hasActiveShift {

                            NavigationLink {
                                FinishDayView(driver: driver)
                            } label: {

                                Text("Finish Day")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(.red.gradient)
                                    .clipShape(
                                        RoundedRectangle(cornerRadius: 20)
                                    )
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
            }
            .toolbar {

                ToolbarItem(placement: .navigationBarTrailing) {

                    Button("Log Out") {
                        logout()
                    }
                }
            }
            .onAppear {

                Task {

                    let loadedLoads =
                        await LoadSupabaseManager.shared.fetchLoads()

                    let loadedSettings =
                        await CompanySupabaseManager
                            .shared
                            .fetchCompanySettings()
                    
                    let loadedShifts =
                        await ShiftSupabaseManager.shared
                            .fetchShifts()
                    
                    let cloudDrivers =
                        await DriverSupabaseManager.shared
                            .fetchDrivers()

                    await MainActor.run {

                        supabaseSettings = loadedSettings
                        supabaseLoads = loadedLoads
                        supabaseShifts = loadedShifts
                        supabaseDriver = cloudDrivers.first {
                            $0.name == driver.name
                        }

                        if hasOldActiveShift {

                            showOldShiftAlert = true

                        } else if !didCheckPendingDeliveries {

                            didCheckPendingDeliveries = true

                            if !pendingDeliveries.isEmpty {

                                print("⚠️ Previous pending loads found:",
                                      pendingDeliveries.count)

                                showPendingDeliveryAlert = true
                            }
                        }
                    }
                }
            }
            .alert(
                "Start Day Required",
                isPresented: $showStartDayRequired
            ) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("You must start your day before adding a load.")
            }
            .alert(
                "Previous Day Still Open",
                isPresented: $showOldShiftAlert
            ) {
                Button("Finish Previous Day") {
                    Task {
                        await finishOldShift()
                    }
                }
            } message: {
                Text(
                    """
                    Your previous shift was not closed.

                    You must finish the previous day before starting a new one.
                    """
                )
            }
            .alert(
                "Pending Deliveries",
                isPresented: $showPendingDeliveryAlert
            ) {

                Button("Complete Deliveries") {
                    showPickupDeliveryView = true
                }

                Button("Later", role: .cancel) { }

            } message: {

                Text(
                    "You have \(pendingDeliveries.count) load(s) still waiting for delivery tickets."
                )
            }

            .sheet(isPresented: $showPickupDeliveryView) {

                NavigationStack {
                    PickupDeliveryView(driver: driver)
                }
            }
        }
    }
    
    func dashboardStat(
        title: String,
        value: String
    ) -> some View {

        VStack(alignment: .leading, spacing: 4) {

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.title.bold())
        }
    }
    
    func ActionCard(
        title: String,
        icon: String,
        color: Color
    ) -> some View {

        VStack(spacing: 12) {

            Image(systemName: icon)
                .font(.largeTitle)

            Text(title)
                .fontWeight(.semibold)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 120)
        .background(color.gradient)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }
    
    func parseSupabaseDate(_ value: String) -> Date? {

        let iso = ISO8601DateFormatter()
        if let date = iso.date(from: value) {
            return date
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ssXXXXX"

        if let date = formatter.date(from: value) {
            return date
        }

        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSSSSXXXXX"

        return formatter.date(from: value)
    }
    
    func finishOldShift() async {

        guard let oldShift = oldActiveShift else {
            print("⚠️ No previous active Supabase shift found")
            return
        }

        let driverLoads =
            await LoadSupabaseManager.shared
                .fetchLoads()
                .filter {
                    $0.driver_name == driver.name &&
                    ($0.is_archived ?? false) == false
                }

        print("📦 Old Shift loads:", driverLoads.count)

        for load in driverLoads {

            if load.status == "delivered" ||
                load.delivered_at != nil {

                print(
                    "✅ Delivered load kept active:",
                    load.pickup_ticket_number ?? ""
                )

            } else {

                print(
                    "⏳ Pending load kept active:",
                    load.pickup_ticket_number ?? ""
                )
            }
        }

        let cloudFinished =
            await ShiftSupabaseManager.shared
                .finishShift(
                    id: oldShift.id
                )

        guard cloudFinished else {
            print("❌ Previous Supabase shift failed to close")
            return
        }

        await DriverSupabaseManager.shared
            .updateDutyStatus(
                username: driver.username,
                dutyStatus: "off_duty"
            )

        let refreshedShifts =
            await ShiftSupabaseManager.shared
                .fetchShifts()

        await MainActor.run {
            supabaseShifts = refreshedShifts
            showOldShiftAlert = false
        }

        print(
            "✅ Previous Supabase shift finished:",
            oldShift.id
        )
    }
    
    func logout() {

        // Old iCloud session tracking disabled
        // DriverSessionManager.logout(
        //     username: driver.username
        // )

        hasSetup = false
        currentDriverName = ""
        isLoggedIn = false
        mustChangePassword = false

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
