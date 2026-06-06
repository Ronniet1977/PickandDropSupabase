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
    
    @State private var showPendingDeliveryAlert = false
    @State private var showPickupDeliveryView = false
    @State private var showOldShiftAlert = false
    
    
    let driver: DriverProfile
    
    var settings: SupabaseCompanySettings? {
        supabaseSettings
    }
    
    var pendingDeliveries: [SupabaseLoad] {
        supabaseLoads.filter { load in

            guard
                load.driver_name == driver.name,
                load.is_archived != true,
                load.delivered_at == nil,
                let pickedString = load.picked_up_at,
                let pickedDate = parseSupabaseDate(pickedString),
                let shiftStart = activeShift?.startedAt
            else {
                return false
            }

            return pickedDate < shiftStart
        }
    }
    
    var hasOldActiveShift: Bool {
        guard let shift = activeShift else { return false }

        return !Calendar.current.isDateInToday(shift.startedAt)
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
    
    var activeShift: Shift? {
        shifts.first(where: {
            $0.driverName == driver.name && $0.status == "active"
        })
    }
    
    var hasActiveShift: Bool {
        activeShift != nil
    }
    
    var activeShiftDuration: String {

        guard let shift = activeShift else {
            return "OFF DUTY"
        }

        let seconds = Int(Date().timeIntervalSince(shift.startedAt))

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

                                    Text("Truck \(driver.truckNumber)")
                                        .foregroundStyle(.white.opacity(0.7))
                                    
                                    Text(
                                        "\(settings?.pickup_company_name ?? "Pickup") → \(settings?.dropoff_company_name ?? "Dropoff")"
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

                                    if let shift = activeShift {

                                        TimelineView(.periodic(from: .now, by: 60)) { context in

                                            let seconds = Int(
                                                context.date.timeIntervalSince(
                                                    shift.startedAt
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

                            HStack {

                                dashboardStat(
                                    title: "Loads",
                                    value: "\(todayLoads.count)"
                                )

                                Spacer()

                                let totalTons = todayLoads.reduce(0.0) {
                                    total,
                                    load in
                                    total + (load.pickup_tons ?? 0)
                                }

                                dashboardStat(
                                    title: "\(settings?.pickup_company_name ?? "Pickup") Tons",
                                    value: String(
                                        format: "%.0f",
                                        totalTons
                                    )
                                )

                                Spacer()

                                let deliveredCount = todayLoads.filter {
                                    $0.status == "delivered"
                                }.count

                                dashboardStat(
                                    title: "\(settings?.dropoff_company_name ?? "Dropoff")",
                                    value: "\(deliveredCount)"
                                )
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

                            NavigationLink {
                                AddLoadView(driver: driver)
                            } label: {

                                ActionCard(
                                    title: "Add Load",
                                    icon: "plus.circle.fill",
                                    color: .blue
                                )
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

                    await MainActor.run {

                        supabaseSettings = loadedSettings
                        supabaseLoads = loadedLoads

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

        let driverLoads =
            await LoadSupabaseManager.shared.fetchLoads()
                .filter {
                    $0.driver_name == driver.name &&
                    ($0.is_archived ?? false) == false
                }

        print("📦 Old Shift loads:", driverLoads.count)

        for load in driverLoads {

            if load.status == "delivered" ||
                load.delivered_at != nil {

                await LoadSupabaseManager.shared.archiveLoad(
                    loadID: load.id
                )

                print("🗂 Archived delivered:",
                      load.pickup_ticket_number ?? "")
            }
        }

        await DriverSupabaseManager.shared.updateDutyStatus(
            username: driver.username,
            dutyStatus: "off_duty"
        )

        if let shift = activeShift {

            shift.status = "finished"

            try? context.save()
        }

        print("✅ Previous shift finished")
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
