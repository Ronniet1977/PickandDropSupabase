import SwiftUI
import SwiftData
import UserNotifications

struct PickupDeliveryView: View {
    let driver: DriverProfile
    
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query var shifts: [Shift]
    
    @State private var settings: SupabaseCompanySettings?
    
    @StateObject private var notificationManager = NotificationSyncManager()
    @State private var deliveryTicket = ""
    @State private var deliveryTons = ""
    
    @State private var supabaseLoads: [SupabaseLoad] = []
    @State private var selectedLoad: SupabaseLoad?
    @State private var supabaseDriver: SupabaseDriver?
    
    @State private var ticketImage: UIImage?
    @State private var showTicketCamera = false
    @State private var isScanningTicket = false
    @State private var scanError = ""
    @State private var showScanError = false
    @State private var selectedScanMode: TicketScanMode = .deliveryOnly
    
    @State private var locations: [SupabaseLocation] = []
    @State private var selectedDeliveryLocation = ""
    
    var dropoffLocations: [SupabaseLocation] {
        locations.filter {
            $0.location_type == "dropoff" ||
            $0.location_type == "both"
        }
    }
    
    var driverLoads: [SupabaseLoad] {
        supabaseLoads
            .filter {
                $0.driver_name == driver.name &&
                $0.is_archived != true &&
                $0.delivered_at == nil
            }
            .sorted {
                ($0.created_at ?? "") > ($1.created_at ?? "")
            }
    }
    
    var activeShift: Shift? {
        shifts.first {
            $0.driverName == driver.name &&
            $0.status.lowercased() == "active"
        }
    }
    
    var currentPickupName: String {
        let name =
        activeShift?.pickupLocation
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
        
        if let name,
           !name.isEmpty {
            return name
        }
        
        return settings?.pickup_company_name
        ?? "Pickup"
    }
    
    var currentDropoffName: String {
        let name =
        activeShift?.dropoffLocation
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
        
        if let name,
           !name.isEmpty {
            return name
        }
        
        return settings?.dropoff_company_name
        ?? "Dropoff"
    }
    
    private var currentTruckNumber: String {
        supabaseDriver?.truck_number ?? driver.truckNumber
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

            ScrollView {

                LazyVStack(spacing: 20) {
                    VStack(spacing: 6) {

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
                    .padding(.bottom, 8)

                    if driverLoads.isEmpty {

                        Text("No loads yet")
                            .foregroundStyle(.white.opacity(0.7))
                            .padding(.top, 40)
                    }

                    ForEach(driverLoads) { load in
                        let pickupName =
                        load.pickup_location
                        ?? settings?.pickup_company_name
                        ?? "Pickup"
                        
                        let dropoffName =
                        selectedDeliveryLocation.isEmpty
                        ? (
                            load.dropoff_location
                            ?? settings?.dropoff_company_name
                            ?? "Dropoff"
                        )
                        : selectedDeliveryLocation

                        VStack(alignment: .leading, spacing: 14) {

                            HStack(alignment: .top) {

                                VStack(alignment: .leading, spacing: 6) {

                                    let ticket = load.pickup_ticket_number ?? ""

                                    Text("\(pickupName) Ticket: \(ticket)")
                                        .font(.title3.bold())
                                        .foregroundStyle(.white)

                                    let tons = load.pickup_tons ?? 0

                                    Text("Tons: \(tons, specifier: "%.2f")")
                                        .font(.subheadline)
                                        .foregroundStyle(.white.opacity(0.7))

                                    if let picked = load.picked_up_at {
                                        Text("Picked up: \(picked)")
                                            .font(.caption)
                                            .foregroundStyle(.orange)
                                    }

                                    if let delivered = load.delivered_at {
                                        Text("Delivered: \(delivered)")
                                            .font(.caption)
                                            .foregroundStyle(.green)
                                    }
                                }

                                Spacer()

                                //Text(statusText(load.status ?? "pickedUp"))
                                    //.font(.caption.bold())
                                    //.padding(.horizontal, 12)
                                    //.padding(.vertical, 8)
                                    //.background(
                                        //statusColor(load.status ?? "pickedUp").opacity(0.2)
                                    //)
                                    //.foregroundStyle(
                                        //statusColor(load.status ?? "pickedUp")
                                    //)
                                    //.clipShape(Capsule())
                            }

                            HStack(spacing: 14) {

                                Button(
                                    "Deliver (\(dropoffName))"
                                ) {
                                    
                                    deliveryTicket = ""
                                    deliveryTons = ""
                                    
                                    selectedDeliveryLocation =
                                    load.dropoff_location
                                    ?? currentDropoffName
                                    
                                    selectedLoad = load
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.green)
                                .disabled(
                                    load.picked_up_at == nil ||
                                    load.delivered_at != nil
                                )
                            }
                        }
                        .padding(20)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 28))
                        .overlay(
                            RoundedRectangle(cornerRadius: 28)
                                .stroke(.white.opacity(0.08))
                        )
                    }
                }
                .padding()
            }
        }
        .navigationTitle(
            "\(currentPickupName) → \(currentDropoffName)"
        )
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .onAppear {
            requestNotificationPermission()

            Task {

                async let loadedSettings =
                    CompanySupabaseManager.shared
                        .fetchCompanySettings()

                async let loadedLoads =
                    LoadSupabaseManager.shared
                        .fetchLoads()

                async let loadedLocations =
                    LocationSupabaseManager.shared
                        .fetchLocations()

                async let loadedDrivers =
                    DriverSupabaseManager.shared
                        .fetchDrivers()

                let newSettings = await loadedSettings
                let newLoads = await loadedLoads
                let newLocations = await loadedLocations
                let cloudDrivers = await loadedDrivers

                await MainActor.run {
                    settings = newSettings
                    supabaseLoads = newLoads
                    locations = newLocations

                    supabaseDriver = cloudDrivers.first {
                        $0.name == driver.name
                    }
                }
            }
        }
        .sheet(item: $selectedLoad) { load in

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

                    VStack(spacing: 28) {

                        Spacer()

                        VStack(spacing: 18) {

                            ZStack {

                                Circle()
                                    .fill(.green.opacity(0.15))
                                    .frame(width: 110, height: 110)

                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 58))
                                    .foregroundStyle(.green)
                            }

                            Text("Complete Delivery")
                                .font(.system(size: 34, weight: .bold))
                                .foregroundStyle(.white)

                            Text(
                                "\(load.pickup_location ?? settings?.pickup_company_name ?? "Pickup") Ticket \(load.pickup_ticket_number ?? "")"
                            )
                            .foregroundStyle(.white.opacity(0.7))
                        }

                        VStack(spacing: 18) {
                            HStack {
                                
                                Text("Deliver To")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.white)
                                
                                Spacer()
                                
                                Picker(
                                    "",
                                    selection: $selectedDeliveryLocation
                                ) {
                                    ForEach(dropoffLocations) { location in
                                        Text(location.name)
                                            .tag(location.name)
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                            }
                            .padding()
                            .background(.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 18))

                            VStack(alignment: .leading, spacing: 8) {
                                let dropoffName =
                                    load.dropoff_location
                                    ?? settings?.dropoff_company_name
                                    ?? ""

                                if dropoffName == "HoneyGo" {

                                    Button {
                                        selectedScanMode = .deliveryOnly
                                        showTicketCamera = true
                                    } label: {

                                        HStack {
                                            Spacer()

                                            if isScanningTicket {
                                                ProgressView()
                                            } else {
                                                Label(
                                                    "Scan HoneyGo Ticket",
                                                    systemImage: "doc.viewfinder.fill"
                                                )
                                            }

                                            Spacer()
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.green)
                                    .disabled(isScanningTicket)

                                } else if dropoffName == "Chase" {

                                    Button {
                                        selectedScanMode = .chaseDeliveryOnly
                                        showTicketCamera = true
                                    } label: {

                                        HStack {
                                            Spacer()

                                            if isScanningTicket {
                                                ProgressView()
                                            } else {
                                                Label(
                                                    "Scan Chase Ticket",
                                                    systemImage: "doc.viewfinder.fill"
                                                )
                                            }

                                            Spacer()
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.green)
                                    .disabled(isScanningTicket)

                                } else {

                                    Text(
                                        "Enter the \(dropoffName.isEmpty ? "delivery" : dropoffName) ticket manually."
                                    )
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }
                                
                                Text(
                                    "\(selectedDeliveryLocation.isEmpty ? (load.dropoff_location ?? settings?.dropoff_company_name ?? "Dropoff") : selectedDeliveryLocation) Ticket"
                                )
                                .font(.caption.bold())
                                .foregroundStyle(.white.opacity(0.7))

                                TextField(
                                    "Enter Ticket Number",
                                    text: $deliveryTicket
                                )
                                .textFieldStyle(.plain)
                                .padding()
                                .background(.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 18))
                                .foregroundStyle(.white)
                            }

                            VStack(alignment: .leading, spacing: 8) {

                                Text(
                                    "\(selectedDeliveryLocation.isEmpty ? (load.dropoff_location ?? settings?.dropoff_company_name ?? "Dropoff") : selectedDeliveryLocation) Tons"
                                )
                                .font(.caption.bold())
                                    .foregroundStyle(.white.opacity(0.7))

                                TextField(
                                    "Enter Tons",
                                    text: $deliveryTons
                                )
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.plain)
                                .padding()
                                .background(.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 18))
                                .foregroundStyle(.white)
                            }
                        }
                        .padding(24)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 30))
                        .padding(.horizontal)

                        Button {
                            Task {
                                await completeDelivery(load)
                            }
                        } label: {

                            HStack {

                                Image(systemName: "checkmark.circle.fill")

                                Text("Complete Delivery")
                                    .fontWeight(.bold)
                            }
                            .disabled(
                                deliveryTicket
                                    .trimmingCharacters(
                                        in: .whitespacesAndNewlines
                                    )
                                    .isEmpty ||
                                (
                                    selectedDeliveryLocation != "Chase" &&
                                    (load.dropoff_location ?? "") != "Chase" &&
                                    (Double(deliveryTons) ?? 0) <= 0
                                ) ||
                                isScanningTicket
                            )
                            .font(.title3)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.green.gradient)
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                        }
                        .padding(.horizontal)

                        Spacer()
                    }
                    .padding()
                }
                .toolbar {

                    ToolbarItem(placement: .topBarTrailing) {

                        Button("Close") {
                            selectedLoad = nil
                        }
                        .foregroundStyle(.white)
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
                        await scanDeliveryTicket(newImage)
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
        }
    }
    
    @MainActor
    private func scanDeliveryTicket(
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
            
            let isChase =
                selectedScanMode == .chaseDeliveryOnly
            
            if isChase {
                
                // Chase is billed per load.
                // We only need the ticket number.
                guard !result.deliveryTicket.isEmpty else {
                    
                    scanError =
                    "The Chase ticket was recognized, but the ticket number could not be read. Try taking the picture again."
                    
                    showScanError = true
                    return
                }
                
            } else {
                
                // HoneyGo needs the delivery
                // ticket and/or tonnage.
                guard
                    !result.deliveryTicket.isEmpty ||
                    !result.deliveryTons.isEmpty
                else {
                    
                    scanError =
                    "The HoneyGo ticket was recognized, but the ticket number and tons could not be read. Try taking the picture again."
                    
                    showScanError = true
                    return
                }
            }
            
            if !result.deliveryTicket.isEmpty {
                deliveryTicket =
                    result.deliveryTicket
            }
            
            // Chase does not need tons.
            if !isChase &&
                !result.deliveryTons.isEmpty {
                
                deliveryTons =
                    result.deliveryTons
            }
            
            if isChase {
                
                print("✅ Chase ticket scanned")
                
            } else {
                
                print("✅ HoneyGo ticket scanned")
            }
            
            print(
                "Ticket:",
                result.deliveryTicket
            )
            
            print(
                "Tons:",
                result.deliveryTons
            )
            
            print(
                "Truck:",
                result.truckNumber
            )
            
        } catch {
            
            scanError =
                error.localizedDescription
            
            showScanError = true
        }
    }
    
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("✅ Notifications allowed")
            } else {
                print("❌ Notifications denied:", error?.localizedDescription ?? "Unknown")
            }
        }
    }
    
    func sendAdminNotification(
        type: String,
        message: String,
        ticket: String? = nil
    ) {
        let note = AppNotification(
            type: type,
            driverName: driver.name,
            truckNumber: currentTruckNumber,
            message: message,
            loadTicket: ticket
        )

        notificationManager.sendNotification(note)
    }
    
    func completeDelivery(
        _ load: SupabaseLoad
    ) async {
        
        let cleanTicket =
        deliveryTicket
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
        
        guard !cleanTicket.isEmpty else {
            return
        }
        
        let dropoffName =
        selectedDeliveryLocation.isEmpty
        ? (
            load.dropoff_location
            ?? settings?.dropoff_company_name
            ?? "Dropoff"
        )
        : selectedDeliveryLocation
        
        let isChase =
            dropoffName == "Chase"
        
        let tonsValue: Double
        
        if isChase {
            
            // Chase is billed per load.
            // Tons are not required.
            tonsValue = 0
            
        } else {
            
            // HoneyGo / per-ton deliveries
            // still require valid tons.
            guard
                let parsedTons =
                    Double(deliveryTons),
                parsedTons > 0
            else {
                return
            }
            
            tonsValue = parsedTons
        }
        
        await LoadSupabaseManager.shared
            .deliverLoad(
                loadID: load.id,
                dropoffLocation:
                    dropoffName,
                deliveryTicketNumber:
                    cleanTicket,
                deliveryTons:
                    tonsValue
            )
        
        let notificationMessage: String
        
        if isChase {
            
            notificationMessage =
                "\(driver.name) delivered \(dropoffName) ticket \(cleanTicket)"
            
        } else {
            
            notificationMessage =
                "\(driver.name) delivered \(dropoffName) ticket \(cleanTicket) • \(tonsValue) tons"
        }
        
        sendAdminNotification(
            type: "Delivered",
            message:
                notificationMessage,
            ticket:
                cleanTicket
        )
        
        await MainActor.run {
            deliveryTicket = ""
            deliveryTons = ""
            selectedLoad = nil
        }
        
        supabaseLoads =
        await LoadSupabaseManager.shared
            .fetchLoads()
    }
    
    func statusText(_ status: String) -> String {
        switch status {
        case "pickedUp": return "Picked Up"
        case "delivered": return "Delivered"
        default: return "New"
        }
    }
    
    func statusColor(_ status: String) -> Color {
        switch status {
        case "pickedUp": return .orange
        case "delivered": return .green
        default: return .gray
        }
    }
}
