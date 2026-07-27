import SwiftUI
import SwiftData

struct DriverDetailView: View {

    @State private var selectedLoad: SupabaseLoad?
    @State private var showAddLoad = false
    @State private var loads: [SupabaseLoad]
    
    init(
        driver: DriverSummary,
        loads: [SupabaseLoad],
        settings: SupabaseCompanySettings?
    ) {
        self.driver = driver
        self.settings = settings
        _loads = State(initialValue: loads)
    }

    let driver: DriverSummary
    let settings: SupabaseCompanySettings?
    
    var grouped: [String: [SupabaseLoad]] {
        [
            "\(settings?.pickup_company_name ?? "Pickup") Loads": loads
        ]
    }
    
    var sortedCompanies: [String] {
        grouped.keys.sorted()
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [.blue.opacity(0.3), .black.opacity(0.2)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                List {
                    Section {
                        VStack(alignment: .leading) {
                            Text(
                                settings?.trucking_company_name
                                ?? "Trucking Company"
                            )
                            .font(.caption.bold())
                            .foregroundStyle(.blue)
                            
                            Text(driver.name)
                                .font(.title.bold())
                            
                            if driver.isFinished {

                                Text("✅ Finished")
                                    .font(.caption)
                                    .foregroundStyle(.green)

                            } else {

                                Text("🟢 Active")
                                    .font(.caption)
                                    .foregroundStyle(.blue)
                            }
                            
                            Text("Truck \(driver.truck)")
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    ForEach(sortedCompanies, id: \.self) { company in
                        
                        if let loads = grouped[company] {
                            
                            let total = loads.reduce(0.0) {
                                $0 + ($1.pickup_tons ?? 0)
                            }
                            
                            Section(
                                header:
                                    VStack(alignment: .leading) {
                                        
                                        Text(company)
                                            .font(.headline)
                                        
                                        Text(
                                            "\(loads.count) loads • \(String(format: "%.0f", total)) tons"
                                        )
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    }
                            ) {
                                
                                ForEach(loads) { load in
                                    
                                    VStack(alignment: .leading, spacing: 8) {

                                        HStack {

                                            Text(
                                                "\(settings?.pickup_company_name ?? "Pickup") Ticket \(load.pickup_ticket_number ?? "")"
                                            )

                                            Spacer()

                                            Text(
                                                "\(load.pickup_tons ?? 0, specifier: "%.0f") Tons"
                                            )
                                            .foregroundStyle(.blue)
                                            .fontWeight(.semibold)
                                        }

                                        if load.status == "delivered" {

                                            HStack {

                                                Text(
                                                    "\(settings?.dropoff_company_name ?? "Dropoff") Ticket \(load.delivery_ticket_number ?? "")"
                                                )

                                                Spacer()

                                                Text(
                                                    "\(load.delivery_tons ?? 0, specifier: "%.0f") Tons"
                                                )
                                                .foregroundStyle(.green)
                                                .fontWeight(.semibold)
                                            }
                                        }
                                    }
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectedLoad = load
                                    }
                                }
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(driver.name)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddLoad = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(item: $selectedLoad) { load in
                NavigationStack {
                    EditSupabaseLoadView(
                        load: load,
                        settings: settings,
                        canDelete: true,
                        onSaved: {
                            Task {
                                await refreshLoads()
                            }
                        }
                    )
                }
            }
            .sheet(isPresented: $showAddLoad) {
                AdminAddLoadView(
                    driverName: driver.name,
                    truckNumber: driver.truck,
                    settings: settings,
                    onSaved: {
                        Task {
                            await refreshLoads()
                        }
                    }
                )
            }
        }
    }
    
    func refreshLoads() async {
        
        let allLoads = await LoadSupabaseManager.shared.fetchLoads()
        
        await MainActor.run {
            loads = allLoads.filter {
                $0.driver_name == driver.name &&
                $0.is_archived != true
            }
        }
    }
}

extension String {
    func trimmed() -> String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension String {
    func cleanedCSV() -> String {
        self
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
    }
}

struct EditSupabaseLoadView: View {
    
    let load: SupabaseLoad
    let settings: SupabaseCompanySettings?
    let canDelete: Bool
    var onSaved: (() -> Void)? = nil
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var pickupTicket = ""
    @State private var pickupTons = ""
    @State private var deliveryTicket = ""
    @State private var deliveryTons = ""
    @State private var status = "pickedUp"
    @State private var showDeleteAlert = false
    @State private var showSavedAlert = false
    
    @State private var drivers: [SupabaseDriver] = []
    @State private var selectedDriverName = ""
    @State private var selectedTruckNumber = ""
    @State private var showMoveLoad = false
    @State private var isMoving = false
    
    var body: some View {
        Form {
            
            Section(settings?.pickup_company_name ?? "Pickup") {
                
                TextField("Ticket Number", text: $pickupTicket)
                
                TextField("Tons", text: $pickupTons)
                    .keyboardType(.decimalPad)
            }
            
            Section(settings?.dropoff_company_name ?? "Dropoff") {
                
                TextField("Ticket Number", text: $deliveryTicket)
                
                TextField("Tons", text: $deliveryTons)
                    .keyboardType(.decimalPad)
            }
            
            Section("Status") {
                
                Picker("Status", selection: $status) {
                    Text("Picked Up").tag("pickedUp")
                    Text("Delivered").tag("delivered")
                }
                .pickerStyle(.segmented)
            }
            
            Button {
                Task {
                    await save()
                }
            } label: {
                Label("Save Changes", systemImage: "checkmark.circle.fill")
            }
            
            Button {
                showMoveLoad = true
            } label: {
                Label(
                    "Move Load",
                    systemImage: "arrow.left.arrow.right.circle.fill"
                )
            }
            
            if canDelete {
                
                Button(role: .destructive) {
                    showDeleteAlert = true
                } label: {
                    Label("Delete Load", systemImage: "trash.fill")
                }
            }
        }
        .navigationTitle("Edit Load")
        .onAppear {
            pickupTicket = load.pickup_ticket_number ?? ""
            pickupTons = String(
                format: "%.2f",
                load.pickup_tons ?? 0
            )
            
            deliveryTicket = load.delivery_ticket_number ?? ""
            deliveryTons = String(
                format: "%.2f",
                load.delivery_tons ?? 0
            )
            
            status = load.status ?? "pickedUp"
            
            Task {
                let loadedDrivers =
                await DriverSupabaseManager.shared.fetchDrivers()
                
                await MainActor.run {
                    drivers = loadedDrivers
                }
            }
        }
        .alert("Delete Load?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            
            Button("Delete", role: .destructive) {
                Task {
                    await deleteLoad()
                }
            }
        } message: {
            Text("This will permanently delete this load from Supabase.")
        }
        .sheet(isPresented: $showMoveLoad) {
            NavigationStack {
                Form {
                    
                    Section("Current Driver") {
                        Text(load.driver_name ?? "Unknown Driver")
                        
                        Text("Truck \(load.truck_number ?? "")")
                            .foregroundStyle(.secondary)
                    }
                    
                    Section("Move To") {
                        Picker(
                            "Driver",
                            selection: $selectedDriverName
                        ) {
                            Text("Select Driver")
                                .tag("")
                            
                            ForEach(drivers, id: \.id) { driver in
                                Text(
                                    "\(driver.name) • Truck \(driver.truck_number)"
                                )
                                .tag(driver.name)
                            }
                        }
                    }
                    
                    Button {
                        Task {
                            await moveLoad()
                        }
                    } label: {
                        Label(
                            isMoving ? "Moving Load..." : "Move Load",
                            systemImage: "arrow.right.circle.fill"
                        )
                    }
                    .disabled(
                        selectedDriverName.isEmpty ||
                        selectedDriverName == load.driver_name ||
                        isMoving
                    )
                }
                .navigationTitle("Move Load")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showMoveLoad = false
                        }
                    }
                }
            }
        }
    }
    
    func save() async {
        
        await LoadSupabaseManager.shared.updateLoad(
            id: load.id,
            pickupTicketNumber: pickupTicket,
            pickupTons: Double(pickupTons) ?? 0,
            deliveryTicketNumber: deliveryTicket,
            deliveryTons: Double(deliveryTons) ?? 0,
            status: status
        )
        
        await MainActor.run {
            onSaved?()
            showSavedAlert = true
        }
    }
    
    func moveLoad() async {
        
        guard !isMoving else {
            return
        }
        
        guard let selectedDriver = drivers.first(where: {
            $0.name == selectedDriverName
        }) else {
            return
        }
        
        await MainActor.run {
            isMoving = true
        }
        
        await LoadSupabaseManager.shared.moveLoad(
            id: load.id,
            driverName: selectedDriver.name,
            truckNumber: selectedDriver.truck_number
        )
        
        await MainActor.run {
            isMoving = false
            showMoveLoad = false
            onSaved?()
            dismiss()
        }
    }
    
    func deleteLoad() async {
        
        await LoadSupabaseManager.shared.deleteLoad(
            id: load.id
        )
        
        await MainActor.run {
            onSaved?()
            dismiss()
        }
    }
}



