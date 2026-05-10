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
    @Query var companySettings: [CompanySettings]
    
    let driver: DriverProfile
    
    var settings: CompanySettings? {
        companySettings.first
    }
    
    var activeShift: Shift? {
        shifts.first(where: {
            $0.driverName == driver.name && $0.status == "active"
        })
    }
    
    var hasActiveShift: Bool {
        activeShift != nil
    }
    
    var shiftLoads: [LoadItem] {
        return loads.filter { $0.driverName == driver.name }
    }
    
    var totalTons: Double {
        shiftLoads.reduce(0.0) { $0 + $1.pickupTons }
    }
    
    var todayLoads: [LoadItem] {

        loads.filter {
            $0.driverName == driver.name
        }
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
                                        settings?.truckingCompanyName
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
                                        "\(settings?.pickupCompanyName ?? "Pickup") → \(settings?.dropoffCompanyName ?? "Dropoff")"
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
                                    total + load.pickupTons
                                }

                                dashboardStat(
                                    title: "\(settings?.pickupCompanyName ?? "Pickup") Tons",
                                    value: String(
                                        format: "%.0f",
                                        totalTons
                                    )
                                )

                                Spacer()

                                let deliveredCount = todayLoads.filter {
                                    $0.isDelivered
                                }.count

                                dashboardStat(
                                    title: "\(settings?.dropoffCompanyName ?? "Dropoff")",
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
