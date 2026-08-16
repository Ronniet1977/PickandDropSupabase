import SwiftUI
import UIKit

import SwiftUI
import UIKit

struct DriverDetailView: View {
    
    let driver: DriverSummary
    let settings: SupabaseCompanySettings?
    
    @State private var selectedLoad: SupabaseLoad?
    @State private var loads: [SupabaseLoad]
    
    @State private var showAddLoad = false
    @State private var showScanCamera = false
    
    @State private var ticketImage: UIImage?
    @State private var scannedLoad: ScannedLoadTicketData?
    
    @State private var selectedScanMode: TicketScanMode = .pickupOnly
    @State private var isScanning = false
    @State private var scanError = ""
    @State private var showScanError = false
    
    init(
        driver: DriverSummary,
        loads: [SupabaseLoad],
        settings: SupabaseCompanySettings?
    ) {
        self.driver = driver
        self.settings = settings
        _loads = State(initialValue: loads)
    }
    
    private var totalPickupTons: Double {
        loads.reduce(0) {
            $0 + ($1.pickup_tons ?? 0)
        }
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    .blue.opacity(0.3),
                    .black.opacity(0.2)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            List {
                driverHeaderSection
                loadSection
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle(driver.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        scannedLoad = nil
                        showAddLoad = true
                    } label: {
                        Label(
                            "Add Load Manually",
                            systemImage: "plus.circle.fill"
                        )
                    }
                    
                    Button {
                        selectedScanMode = .pickupOnly
                        showScanCamera = true
                    } label: {
                        Label(
                            "Scan BRC Ticket",
                            systemImage: "arrow.up.doc.fill"
                        )
                    }
                    
                    Button {
                        selectedScanMode = .deliveryOnly
                        showScanCamera = true
                    } label: {
                        Label(
                            "Scan HoneyGo Ticket",
                            systemImage: "arrow.down.doc.fill"
                        )
                    }
                } label: {
                    Label(
                        isScanning ? "Scanning..." : "Load",
                        systemImage: "shippingbox.fill"
                    )
                }
                .disabled(isScanning)
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
        .sheet(isPresented: $showScanCamera) {
            CameraPicker(image: $ticketImage)
        }
        .sheet(isPresented: $showAddLoad) {
            NavigationStack {
                AdminAddLoadView(
                    driverName: driver.name,
                    truckNumber: driver.truck,
                    settings: settings,
                    scannedLoad: scannedLoad,
                    onSaved: {
                        Task {
                            await refreshLoads()
                        }
                    }
                )
            }
        }
        .onChange(of: ticketImage) { _, newImage in
            guard let newImage else {
                return
            }
            
            Task {
                await scanNewLoad(image: newImage)
            }
        }
        .alert(
            "Ticket Scan Failed",
            isPresented: $showScanError
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(scanError)
        }
    }
    
    private var driverHeaderSection: some View {
        Section {
            DriverDetailHeader(
                driver: driver,
                companyName:
                    settings?.trucking_company_name
                ?? "Trucking Company"
            )
        }
    }
    
    private var loadSection: some View {
        Section {
            if loads.isEmpty {
                ContentUnavailableView(
                    "No Loads",
                    systemImage: "shippingbox",
                    description: Text(
                        "Use the Load menu to add or scan a load for \(driver.name)."
                    )
                )
            } else {
                ForEach(loads) { load in
                    DriverLoadRow(
                        load: load,
                        pickupCompany:
                            settings?.pickup_company_name
                        ?? "Pickup",
                        dropoffCompany:
                            settings?.dropoff_company_name
                        ?? "Dropoff"
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedLoad = load
                    }
                }
            }
        } header: {
            VStack(alignment: .leading, spacing: 3) {
                Text(
                    "\(settings?.pickup_company_name ?? "Pickup") Loads"
                )
                .font(.headline)
                
                Text(
                    "\(loads.count) loads • "
                    + String(
                        format: "%.0f tons",
                        totalPickupTons
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }
    
    @MainActor
    private func scanNewLoad(
        image: UIImage
    ) async {
        guard !isScanning else {
            return
        }
        
        isScanning = true
        
        defer {
            isScanning = false
            ticketImage = nil
        }
        
        do {
            let result =
            try await ScaleTicketOCR.scan(
                image: image,
                mode: selectedScanMode
            )
            
            scannedLoad = result
            showScanCamera = false
            
            try? await Task.sleep(
                for: .milliseconds(250)
            )
            
            showAddLoad = true
            
            print("✅ New admin ticket scan complete")
            print(result.rawText)
            
        } catch {
            scanError = error.localizedDescription
            showScanError = true
        }
    }
    
    @MainActor
    private func refreshLoads() async {
        let allLoads =
        await LoadSupabaseManager.shared.fetchLoads()
        
        loads = allLoads.filter {
            $0.driver_name == driver.name &&
            $0.is_archived != true
        }
    }
}

private struct DriverDetailHeader: View {
    
    let driver: DriverSummary
    let companyName: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(companyName)
                .font(.caption.bold())
                .foregroundStyle(.blue)
            
            Text(driver.name)
                .font(.title.bold())
            
            Label(
                statusText,
                systemImage: statusIcon
            )
            .font(.caption)
            .foregroundStyle(statusColor)
            
            Text("Truck \(driver.truck)")
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    private var statusText: String {
        driver.isFinished ? "Finished" : driver.status
    }
    
    private var statusIcon: String {
        driver.isFinished
        ? "checkmark.circle.fill"
        : "circle.fill"
    }
    
    private var statusColor: Color {
        driver.isFinished ? .green : .blue
    }
}

private struct DriverLoadRow: View {
    
    let load: SupabaseLoad
    let pickupCompany: String
    let dropoffCompany: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(pickupDescription)
                
                Spacer()
                
                Text(
                    "\(load.pickup_tons ?? 0, specifier: "%.2f") Tons"
                )
                .foregroundStyle(.blue)
                .fontWeight(.semibold)
            }
            
            if load.status == "delivered" {
                HStack {
                    Text(deliveryDescription)
                    
                    Spacer()
                    
                    Text(
                        "\(load.delivery_tons ?? 0, specifier: "%.2f") Tons"
                    )
                    .foregroundStyle(.green)
                    .fontWeight(.semibold)
                }
            } else {
                Label(
                    "Awaiting delivery",
                    systemImage: "clock.fill"
                )
                .font(.caption)
                .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var pickupDescription: String {
        let ticket = load.pickup_ticket_number?
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            ) ?? ""
        
        return ticket.isEmpty
        ? "\(pickupCompany) Ticket — Missing"
        : "\(pickupCompany) Ticket \(ticket)"
    }
    
    private var deliveryDescription: String {
        let ticket = load.delivery_ticket_number?
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            ) ?? ""
        
        return ticket.isEmpty
        ? "\(dropoffCompany) Ticket — Missing"
        : "\(dropoffCompany) Ticket \(ticket)"
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
    @State private var showMoveLoad = false
    @State private var isMoving = false
    
    @State private var ticketImage: UIImage?
    @State private var showTicketCamera = false
    @State private var selectedScanMode: TicketScanMode = .pickupOnly
    @State private var isScanningTicket = false
    @State private var scanError = ""
    @State private var showScanError = false
    
    var body: some View {
        Form {
            Section("Scan Ticket") {
                Button {
                    selectedScanMode = .pickupOnly
                    showTicketCamera = true
                } label: {
                    Label(
                        "Scan BRC Ticket",
                        systemImage: "arrow.up.doc.fill"
                    )
                }
                
                Button {
                    selectedScanMode = .deliveryOnly
                    showTicketCamera = true
                } label: {
                    Label(
                        "Scan HoneyGo Ticket",
                        systemImage: "arrow.down.doc.fill"
                    )
                }
            }
            .disabled(isScanningTicket)
            
            if isScanningTicket {
                Section {
                    HStack {
                        Spacer()
                        ProgressView("Scanning ticket...")
                        Spacer()
                    }
                }
            }
            
            Section(
                settings?.pickup_company_name
                ?? "Pickup"
            ) {
                TextField(
                    "Ticket Number",
                    text: $pickupTicket
                )
                
                TextField(
                    "Tons",
                    text: $pickupTons
                )
                .keyboardType(.decimalPad)
            }
            
            Section(
                settings?.dropoff_company_name
                ?? "Dropoff"
            ) {
                TextField(
                    "Ticket Number",
                    text: $deliveryTicket
                )
                
                TextField(
                    "Tons",
                    text: $deliveryTons
                )
                .keyboardType(.decimalPad)
            }
            
            Section("Status") {
                Picker(
                    "Status",
                    selection: $status
                ) {
                    Text("Picked Up")
                        .tag("pickedUp")
                    
                    Text("Delivered")
                        .tag("delivered")
                }
                .pickerStyle(.segmented)
            }
            
            Button {
                Task {
                    await save()
                }
            } label: {
                Label(
                    "Save Changes",
                    systemImage: "checkmark.circle.fill"
                )
            }
            
            Button {
                showMoveLoad = true
            } label: {
                Label(
                    "Move Load",
                    systemImage:
                        "arrow.left.arrow.right.circle.fill"
                )
            }
            
            if canDelete {
                Button(role: .destructive) {
                    showDeleteAlert = true
                } label: {
                    Label(
                        "Delete Load",
                        systemImage: "trash.fill"
                    )
                }
            }
        }
        .navigationTitle("Edit Load")
        .onAppear {
            pickupTicket =
            load.pickup_ticket_number ?? ""
            
            pickupTons =
            String(
                format: "%.2f",
                load.pickup_tons ?? 0
            )
            
            deliveryTicket =
            load.delivery_ticket_number ?? ""
            
            deliveryTons =
            String(
                format: "%.2f",
                load.delivery_tons ?? 0
            )
            
            status =
            load.status ?? "pickedUp"
            
            Task {
                let loadedDrivers =
                await DriverSupabaseManager
                    .shared
                    .fetchDrivers()
                
                await MainActor.run {
                    drivers = loadedDrivers
                }
            }
        }
        .alert(
            "Load Updated",
            isPresented: $showSavedAlert
        ) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("The load changes were saved.")
        }
        .alert(
            "Delete Load?",
            isPresented: $showDeleteAlert
        ) {
            Button("Cancel", role: .cancel) { }
            
            Button(
                "Delete",
                role: .destructive
            ) {
                Task {
                    await deleteLoad()
                }
            }
        } message: {
            Text(
                "This will permanently delete this load from Supabase."
            )
        }
        .alert(
            "Ticket Scan Failed",
            isPresented: $showScanError
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(scanError)
        }
        .sheet(isPresented: $showTicketCamera) {
            CameraPicker(image: $ticketImage)
        }
        .sheet(isPresented: $showMoveLoad) {
            NavigationStack {
                Form {
                    Section("Current Driver") {
                        Text(
                            load.driver_name
                            ?? "Unknown Driver"
                        )
                        
                        Text(
                            "Truck \(load.truck_number ?? "")"
                        )
                        .foregroundStyle(.secondary)
                    }
                    
                    Section("Move To") {
                        Picker(
                            "Driver",
                            selection: $selectedDriverName
                        ) {
                            Text("Select Driver")
                                .tag("")
                            
                            ForEach(
                                drivers,
                                id: \.id
                            ) { driver in
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
                            isMoving
                            ? "Moving Load..."
                            : "Move Load",
                            systemImage:
                                "arrow.right.circle.fill"
                        )
                    }
                    .disabled(
                        selectedDriverName.isEmpty ||
                        selectedDriverName ==
                        load.driver_name ||
                        isMoving
                    )
                }
                .navigationTitle("Move Load")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(
                        placement: .cancellationAction
                    ) {
                        Button("Cancel") {
                            showMoveLoad = false
                        }
                    }
                }
            }
        }
        .onChange(of: ticketImage) { _, newImage in
            guard let newImage else {
                return
            }
            
            Task {
                await scanSingleTicket(newImage)
            }
        }
    }
    
    func save() async {
        await LoadSupabaseManager.shared.updateLoad(
            id: load.id,
            pickupTicketNumber:
                pickupTicket.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ),
            pickupTons:
                Double(pickupTons) ?? 0,
            deliveryTicketNumber:
                deliveryTicket.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ),
            deliveryTons:
                Double(deliveryTons) ?? 0,
            status: status,
            existingDeliveredAt:
                load.delivered_at
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
        
        guard let selectedDriver =
                drivers.first(where: {
                    $0.name == selectedDriverName
                })
        else {
            return
        }
        
        await MainActor.run {
            isMoving = true
        }
        
        await LoadSupabaseManager.shared.moveLoad(
            id: load.id,
            driverName: selectedDriver.name,
            truckNumber:
                selectedDriver.truck_number
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
    
    @MainActor
    private func scanSingleTicket(
        _ image: UIImage
    ) async {
        guard !isScanningTicket else {
            return
        }
        
        isScanningTicket = true
        
        defer {
            isScanningTicket = false
            ticketImage = nil
        }
        
        do {
            let result =
            try await ScaleTicketOCR.scan(
                image: image,
                mode: selectedScanMode
            )
            
            switch selectedScanMode {
            case .pickupOnly:
                if !result.pickupTicket.isEmpty {
                    pickupTicket =
                    result.pickupTicket
                }
                
                if !result.pickupTons.isEmpty {
                    pickupTons =
                    result.pickupTons
                }
                
                print("✅ Edit BRC ticket scanned")
                
            case .deliveryOnly:
                if !result.deliveryTicket.isEmpty {
                    deliveryTicket =
                    result.deliveryTicket
                }
                
                if !result.deliveryTons.isEmpty {
                    deliveryTons =
                    result.deliveryTons
                }
                
                if !deliveryTicket.isEmpty &&
                    (Double(deliveryTons) ?? 0) > 0 {
                    
                    status = "delivered"
                }
                
                print(
                    "✅ Edit HoneyGo ticket scanned"
                )
                
            case .combined:
                break
            }
            
            print(result.rawText)
            
        } catch {
            scanError =
            error.localizedDescription
            
            showScanError = true
        }
    }
}
    
//AdminAddLoadView
struct AdminAddLoadView: View {
    
    let driverName: String
    let truckNumber: String
    let settings: SupabaseCompanySettings?
    let scannedLoad: ScannedLoadTicketData?
    
    var onSaved: (() -> Void)? = nil
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var pickupTicket = ""
    @State private var pickupTons = ""
    
    @State private var deliveryTicket = ""
    @State private var deliveryTons = ""
    
    @State private var status = "pickedUp"
    @State private var isSaving = false
    
    @State private var ticketImage: UIImage?
    @State private var showTicketCamera = false
    @State private var selectedScanMode: TicketScanMode = .pickupOnly
    @State private var isScanningTicket = false
    @State private var scanError = ""
    @State private var showScanError = false
    
    var body: some View {
        Form {
            Section(driverName) {
                Text("Truck \(truckNumber)")
                    .foregroundStyle(.secondary)
                
                if scannedLoad != nil {
                    Label(
                        "Values filled from ticket scan",
                        systemImage:
                            "doc.viewfinder.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(.green)
                }
            }
            
            Section("Scan Ticket") {
                Button {
                    selectedScanMode = .pickupOnly
                    showTicketCamera = true
                } label: {
                    Label(
                        "Scan BRC Ticket",
                        systemImage: "arrow.up.doc.fill"
                    )
                }
                
                Button {
                    selectedScanMode = .deliveryOnly
                    showTicketCamera = true
                } label: {
                    Label(
                        "Scan HoneyGo Ticket",
                        systemImage: "arrow.down.doc.fill"
                    )
                }
            }
            .disabled(isScanningTicket)
            
            if isScanningTicket {
                Section {
                    HStack {
                        Spacer()
                        ProgressView("Scanning ticket...")
                        Spacer()
                    }
                }
            }
            
            Section(
                settings?.pickup_company_name
                ?? "Pickup"
            ) {
                TextField(
                    "Ticket Number",
                    text: $pickupTicket
                )
                
                TextField(
                    "Tons",
                    text: $pickupTons
                )
                .keyboardType(.decimalPad)
            }
            
            Section(
                settings?.dropoff_company_name
                ?? "Dropoff"
            ) {
                TextField(
                    "Ticket Number",
                    text: $deliveryTicket
                )
                
                TextField(
                    "Tons",
                    text: $deliveryTons
                )
                .keyboardType(.decimalPad)
            }
            
            Section("Status") {
                Picker(
                    "Status",
                    selection: $status
                ) {
                    Text("Picked Up")
                        .tag("pickedUp")
                    
                    Text("Delivered")
                        .tag("delivered")
                }
                .pickerStyle(.segmented)
            }
            
            Button {
                Task {
                    await addLoad()
                }
            } label: {
                HStack {
                    Spacer()
                    
                    if isSaving {
                        ProgressView()
                    } else {
                        Label(
                            "Save Load",
                            systemImage:
                                "checkmark.circle.fill"
                        )
                    }
                    
                    Spacer()
                }
            }
            .disabled(
                !isValidLoad ||
                isSaving ||
                isScanningTicket
            )
        }
        .navigationTitle(
            scannedLoad == nil
            ? "Add Load"
            : "Review Scanned Load"
        )
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(
                placement: .cancellationAction
            ) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
        .onAppear {
            guard let scannedLoad else {
                return
            }
            
            if !scannedLoad.pickupTicket.isEmpty {
                pickupTicket =
                scannedLoad.pickupTicket
            }
            
            if !scannedLoad.pickupTons.isEmpty {
                pickupTons =
                scannedLoad.pickupTons
            }
            
            if !scannedLoad.deliveryTicket.isEmpty {
                deliveryTicket =
                scannedLoad.deliveryTicket
            }
            
            if !scannedLoad.deliveryTons.isEmpty {
                deliveryTons =
                scannedLoad.deliveryTons
            }
            
            if !deliveryTicket.isEmpty &&
                (Double(deliveryTons) ?? 0) > 0 {
                
                status = "delivered"
            }
        }
        .sheet(isPresented: $showTicketCamera) {
            CameraPicker(image: $ticketImage)
        }
        .onChange(of: ticketImage) { _, newImage in
            guard let newImage else {
                return
            }
            
            Task {
                await scanSingleTicket(newImage)
            }
        }
        .alert(
            "Ticket Scan Failed",
            isPresented: $showScanError
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(scanError)
        }
    }
    
    private var isValidLoad: Bool {
        guard
            (Double(pickupTons) ?? 0) > 0
        else {
            return false
        }
        
        if status != "delivered" {
            return true
        }
        
        return
        !deliveryTicket
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .isEmpty &&
        (Double(deliveryTons) ?? 0) > 0
    }
    
    private func addLoad() async {
        guard !isSaving else {
            return
        }
        
        guard
            let settings,
            let pickupTonsValue =
                Double(pickupTons),
            pickupTonsValue > 0
        else {
            return
        }
        
        let deliveryTonsValue =
        Double(deliveryTons) ?? 0
        
        await MainActor.run {
            isSaving = true
        }
        
        await LoadSupabaseManager.shared
            .addAdminLoad(
                driverName: driverName,
                truckNumber: truckNumber,
                pickupTicketNumber:
                    pickupTicket.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ),
                pickupTons: pickupTonsValue,
                deliveryTicketNumber:
                    deliveryTicket.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ),
                deliveryTons: deliveryTonsValue,
                status: status,
                ratePerTon:
                    settings.rate_per_ton,
                fuelSurchargePerTon:
                    settings.fuel_surcharge_per_ton
            )
        
        await MainActor.run {
            onSaved?()
            dismiss()
        }
    }
    
    @MainActor
    private func scanSingleTicket(
        _ image: UIImage
    ) async {
        guard !isScanningTicket else {
            return
        }
        
        isScanningTicket = true
        
        defer {
            isScanningTicket = false
            ticketImage = nil
        }
        
        do {
            let result =
            try await ScaleTicketOCR.scan(
                image: image,
                mode: selectedScanMode
            )
            
            switch selectedScanMode {
            case .pickupOnly:
                if !result.pickupTicket.isEmpty {
                    pickupTicket =
                    result.pickupTicket
                }
                
                if !result.pickupTons.isEmpty {
                    pickupTons =
                    result.pickupTons
                }
                
                print("✅ Admin BRC ticket scanned")
                
            case .deliveryOnly:
                if !result.deliveryTicket.isEmpty {
                    deliveryTicket =
                    result.deliveryTicket
                }
                
                if !result.deliveryTons.isEmpty {
                    deliveryTons =
                    result.deliveryTons
                }
                
                if !deliveryTicket.isEmpty &&
                    (Double(deliveryTons) ?? 0) > 0 {
                    
                    status = "delivered"
                }
                
                print(
                    "✅ Admin HoneyGo ticket scanned"
                )
                
            case .combined:
                break
            }
            
            print(result.rawText)
            
        } catch {
            scanError =
            error.localizedDescription
            
            showScanError = true
        }
    }
}

    
    


