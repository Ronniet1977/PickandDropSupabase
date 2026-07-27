import SwiftUI

struct AdminLoadManagementView: View {
    
    @State private var drivers: [SupabaseDriver] = []
    @State private var loads: [SupabaseLoad] = []
    @State private var settings: SupabaseCompanySettings?
    @State private var isLoading = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                
                if isLoading && drivers.isEmpty {
                    ProgressView("Loading drivers...")
                        .padding(.top, 40)
                }
                
                if !isLoading && drivers.isEmpty {
                    ContentUnavailableView(
                        "No Drivers",
                        systemImage: "person.3.fill",
                        description: Text("No drivers were found in Supabase.")
                    )
                    .padding(.top, 40)
                }
                
                ForEach(drivers, id: \.id) { driver in
                    AdminDriverLoadCard(
                        driver: driver,
                        loads: loads,
                        settings: settings
                    )
                }
            }
            .padding()
        }
        .navigationTitle("Manage Loads")
        .refreshable {
            await loadData()
        }
        .task {
            await loadData()
        }
    }
    
    @MainActor
    private func loadData() async {
        guard !isLoading else {
            return
        }
        
        isLoading = true
        
        async let loadedDrivers =
        DriverSupabaseManager.shared.fetchDrivers()
        
        async let loadedLoads =
        LoadSupabaseManager.shared.fetchLoads()
        
        async let loadedSettings =
        CompanySupabaseManager.shared.fetchCompanySettings()
        
        drivers = await loadedDrivers
        loads = await loadedLoads
        settings = await loadedSettings
        
        isLoading = false
    }
}

struct AdminDriverLoadCard: View {
    
    let driver: SupabaseDriver
    let loads: [SupabaseLoad]
    let settings: SupabaseCompanySettings?
    
    private var driverLoads: [SupabaseLoad] {
        loads.filter {
            $0.driver_name == driver.name &&
            $0.is_archived != true
        }
    }
    
    private var pickupTons: Double {
        driverLoads.reduce(0.0) {
            $0 + ($1.pickup_tons ?? 0)
        }
    }
    
    private var deliveryTons: Double {
        driverLoads.reduce(0.0) {
            $0 + ($1.delivery_tons ?? 0)
        }
    }
    
    private var deliveredCount: Int {
        driverLoads.filter {
            $0.status == "delivered"
        }
        .count
    }
    
    private var driverSummary: DriverSummary {
        DriverSummary(
            name: driver.name,
            truck: driver.truck_number,
            loads: driverLoads.count,
            pickupTons: pickupTons,
            deliveryTons: deliveryTons,
            fuel: 0,
            status: driver.is_active ? "Active" : "Inactive",
            isFinished: false
        )
    }
    
    var body: some View {
        NavigationLink {
            DriverDetailView(
                driver: driverSummary,
                loads: driverLoads,
                settings: settings
            )
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(driver.name)
                            .font(.title2.bold())
                        
                        Text("Truck \(driver.truck_number)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
                
                HStack {
                    Label(
                        "\(driverLoads.count) Loads",
                        systemImage: "shippingbox.fill"
                    )
                    
                    Spacer()
                    
                    Label(
                        "\(deliveredCount) Delivered",
                        systemImage: "checkmark.circle.fill"
                    )
                    .foregroundStyle(.green)
                }
                .font(.caption)
                
                Divider()
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Pickup Tons")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        
                        Text("\(pickupTons, specifier: "%.2f")")
                            .font(.headline)
                            .foregroundStyle(.blue)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Delivery Tons")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        
                        Text("\(deliveryTons, specifier: "%.2f")")
                            .font(.headline)
                            .foregroundStyle(.green)
                    }
                }
            }
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
            .padding()
            .background(AppTheme.cardBackground)
            .clipShape(
                RoundedRectangle(cornerRadius: 24)
            )
        }
        .buttonStyle(.plain)
    }
}



