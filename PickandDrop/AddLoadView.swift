import SwiftUI
import SwiftData

struct AddLoadView: View {
    let driver: DriverProfile
    
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    @Query var shifts: [Shift]
    
    @StateObject private var notificationManager = NotificationSyncManager()
    @State private var settings: SupabaseCompanySettings?

    @State private var pickupTicket = ""
    @State private var pickupTons = ""
    
    @State private var ticketImage: UIImage?
    @State private var showTicketCamera = false
    @State private var isScanningTicket = false
    @State private var scanError = ""
    @State private var showScanError = false
    @State private var locations: [SupabaseLocation] = []
    
    @State private var selectedPickupLocation = ""
    @State private var selectedDropoffLocation = ""
    @State private var supabaseDriver: SupabaseDriver?
    
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
    
    var activeShift: Shift? {
        shifts.first(where: {
            $0.driverName == driver.name &&
            $0.status.lowercased() == "active"
        })
    }
    
    var isValidLoad: Bool {

        if isPerLoadRoute {
            return true
        }

        return (Double(pickupTons) ?? 0) > 0
    }
    
    private var selectedDropoff: SupabaseLocation? {
        locations.first {
            $0.name == selectedDropoffLocation
        }
    }

    private var isPerLoadRoute: Bool {
        selectedDropoff?.billing_type == "per_load"
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

            ScrollView {

                VStack(spacing: 28) {

                    Spacer(minLength: 20)

                    VStack(spacing: 18) {

                        ZStack {

                            Circle()
                                .fill(.blue.opacity(0.15))
                                .frame(width: 120, height: 120)

                            Image(systemName: "shippingbox.fill")
                                .font(.system(size: 58))
                                .foregroundStyle(.blue)
                        }

                        Text("Add Load")
                            .font(.system(size: 38, weight: .bold))
                            .foregroundStyle(.white)
                        
                        Text(
                            "\(selectedPickupLocation.isEmpty ? (activeShift?.pickupLocation ?? settings?.pickup_company_name ?? "Pickup") : selectedPickupLocation) → \(selectedDropoffLocation.isEmpty ? (activeShift?.dropoffLocation ?? settings?.dropoff_company_name ?? "Dropoff") : selectedDropoffLocation)"
                        )
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.blue.opacity(0.15))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())

                        Text(driver.name)
                            .foregroundStyle(.white.opacity(0.7))

                        Text("Truck \(currentTruckNumber)")
                            .foregroundStyle(.white.opacity(0.5))
                    }

                    if activeShift == nil {

                        VStack(spacing: 14) {

                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.largeTitle)
                                .foregroundStyle(.red)

                            Text("No Active Shift")
                                .font(.title2.bold())
                                .foregroundStyle(.white)

                            Text("Start your day before adding loads.")
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(28)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 30))
                        .padding(.horizontal)

                    } else {

                        VStack(spacing: 22) {

                            VStack(alignment: .leading, spacing: 8) {
                                VStack(alignment: .leading, spacing: 12) {
                                    
                                    Text("Route")
                                        .font(.caption.bold())
                                        .foregroundStyle(.white.opacity(0.7))
                                    
                                    HStack {
                                        
                                        Text("Pickup")
                                            .font(.subheadline.bold())
                                            .foregroundStyle(.white)
                                        
                                        Spacer()
                                        
                                        Picker(
                                            "",
                                            selection: $selectedPickupLocation
                                        ) {
                                            ForEach(pickupLocations) { location in
                                                Text(location.name)
                                                    .tag(location.name)
                                            }
                                        }
                                        .labelsHidden()
                                        .pickerStyle(.menu)
                                    }
                                    
                                    Divider()
                                        .overlay(.white.opacity(0.15))
                                    
                                    HStack {
                                        
                                        Text("Dropoff")
                                            .font(.subheadline.bold())
                                            .foregroundStyle(.white)
                                        
                                        Spacer()
                                        
                                        Picker(
                                            "",
                                            selection: $selectedDropoffLocation
                                        ) {
                                            ForEach(dropoffLocations) { location in
                                                Text(location.name)
                                                    .tag(location.name)
                                            }
                                        }
                                        .labelsHidden()
                                        .pickerStyle(.menu)
                                    }
                                }
                                .padding()
                                .background(.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 18))
                                
                                Button {
                                    showTicketCamera = true
                                } label: {
                                    HStack {
                                        Spacer()
                                        
                                        if isScanningTicket {
                                            ProgressView()
                                        } else {
                                            Label(
                                                "Scan BRC Ticket",
                                                systemImage: "doc.viewfinder.fill"
                                            )
                                        }
                                        
                                        Spacer()
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(isScanningTicket)

                                Text(
                                    "\(selectedPickupLocation.isEmpty ? (activeShift?.pickupLocation ?? settings?.pickup_company_name ?? "Pickup") : selectedPickupLocation) Ticket Number (Optional)"
                                )
                                    .font(.caption.bold())
                                    .foregroundStyle(.white.opacity(0.7))

                                TextField(
                                    "Optional - enter later",
                                    text: $pickupTicket
                                )
                                .textFieldStyle(.plain)
                                .padding()
                                .background(.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 18))
                                .foregroundStyle(.white)
                            }

                            if !isPerLoadRoute {

                                VStack(alignment: .leading, spacing: 8) {

                                    Text(
                                        "\(selectedPickupLocation.isEmpty ? (activeShift?.pickupLocation ?? settings?.pickup_company_name ?? "Pickup") : selectedPickupLocation) Tons"
                                    )
                                    .font(.caption.bold())
                                    .foregroundStyle(.white.opacity(0.7))

                                    TextField(
                                        "Enter Tons",
                                        text: $pickupTons
                                    )
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(.plain)
                                    .padding()
                                    .background(.white.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 18))
                                    .foregroundStyle(.white)

                                    if !pickupTons.isEmpty &&
                                        Double(pickupTons) == nil {

                                        HStack {

                                            Image(
                                                systemName:
                                                    "exclamationmark.circle.fill"
                                            )

                                            Text(
                                                "Enter a valid number for tons"
                                            )
                                        }
                                        .font(.caption.bold())
                                        .foregroundStyle(.red)
                                        .frame(
                                            maxWidth: .infinity,
                                            alignment: .leading
                                        )
                                    }
                                }
                            }
                        }
                        .padding(26)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 30))
                        .padding(.horizontal)

                        Button {
                            Task {
                                await saveLoad()
                            }
                        } label: {

                            HStack(spacing: 14) {

                                Image(systemName: "plus.circle.fill")

                                Text("Save Load")
                                    .fontWeight(.bold)
                            }
                            .font(.title3)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.blue.gradient)
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                            .shadow(color: .blue.opacity(0.4), radius: 14)
                        }
                        .padding(.horizontal)
                        .disabled(!isValidLoad || activeShift == nil)
                    }

                    Spacer(minLength: 40)
                }
                .padding()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .onAppear {
            Task {

                async let loadedSettings =
                    CompanySupabaseManager.shared
                        .fetchCompanySettings()

                async let loadedLocations =
                    LocationSupabaseManager.shared
                        .fetchLocations()

                async let loadedDrivers =
                    DriverSupabaseManager.shared
                        .fetchDrivers()

                let newSettings = await loadedSettings
                let newLocations = await loadedLocations
                let cloudDrivers = await loadedDrivers

                await MainActor.run {

                    settings = newSettings
                    locations = newLocations

                    supabaseDriver = cloudDrivers.first {
                        $0.name == driver.name
                    }

                    if let shift = activeShift {

                        selectedPickupLocation =
                            shift.pickupLocation

                        selectedDropoffLocation =
                            shift.dropoffLocation
                    }

                    if selectedPickupLocation.isEmpty {
                        selectedPickupLocation =
                            newLocations.first {
                                $0.location_type == "pickup" ||
                                $0.location_type == "both"
                            }?.name
                            ?? newSettings?.pickup_company_name
                            ?? ""
                    }

                    if selectedDropoffLocation.isEmpty {
                        selectedDropoffLocation =
                            newLocations.first {
                                $0.location_type == "dropoff" ||
                                $0.location_type == "both"
                            }?.name
                            ?? newSettings?.dropoff_company_name
                            ?? ""
                    }
                }
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
                await scanPickupTicket(newImage)
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
    
    @MainActor
    private func scanPickupTicket(
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
                mode: .pickupOnly
            )
            
            guard
                !result.pickupTicket.isEmpty ||
                    !result.pickupTons.isEmpty
            else {
                
                scanError =
                "The BRC ticket was recognized, but the ticket number and tons could not be read. Try taking the picture again."
                
                showScanError = true
                return
            }
            
            if !result.pickupTicket.isEmpty {
                pickupTicket =
                result.pickupTicket
            }
            
            if !result.pickupTons.isEmpty {
                pickupTons =
                result.pickupTons
            }
            
            print("✅ BRC ticket scanned")
            print(
                "Ticket:",
                result.pickupTicket
            )
            print(
                "Tons:",
                result.pickupTons
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
    
    func saveLoad() async {
        
        let cleanTicket =
        pickupTicket.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let displayTicket =
        cleanTicket.isEmpty ? "No pickup ticket yet" : cleanTicket
        
        // ✅ Save load to Supabase
        guard let settings else {
            print("❌ Company settings missing")
            return
        }
        
        guard
            !selectedPickupLocation.isEmpty,
            !selectedDropoffLocation.isEmpty
        else {
            print("❌ Load route missing")
            return
        }
        
        let selectedDropoff =
        locations.first {
            $0.name == selectedDropoffLocation
        }
        
        let billingType =
        selectedDropoff?.billing_type
        ?? "per_ton"
        
        let tonsValue: Double

        if billingType == "per_load" ||
           billingType == "per_hour" {

            // Per-load/per-hour routes do not use tons.
            tonsValue = 0

        } else {

            guard let enteredTons = Double(pickupTons),
                  enteredTons > 0
            else {
                print("❌ Valid pickup tons required")
                return
            }

            tonsValue = enteredTons
        }
        
        let ratePerTon: Double
        let fuelSurchargePerTon: Double
        let ratePerLoad: Double
        let ratePerHour: Double
        
        switch billingType {
            
        case "per_load":
            ratePerTon = 0
            fuelSurchargePerTon = 0
            ratePerLoad =
            selectedDropoff?.rate_per_load ?? 0
            ratePerHour = 0
            
        case "per_hour":
            ratePerTon = 0
            fuelSurchargePerTon = 0
            ratePerLoad = 0
            ratePerHour =
            selectedDropoff?.rate_per_hour ?? 0
            
        default:
            ratePerTon =
            selectedDropoff?.rate_per_ton
            ?? settings.rate_per_ton
            
            fuelSurchargePerTon =
            selectedDropoff?.fuel_surcharge_per_ton
            ?? settings.fuel_surcharge_per_ton
            
            ratePerLoad = 0
            ratePerHour = 0
        }
        
        await LoadSupabaseManager.shared.addLoad(
            driverName: driver.name,
            truckNumber: currentTruckNumber,
            
            pickupLocation:
                selectedPickupLocation,
            
            dropoffLocation:
                selectedDropoffLocation,
            
            pickupTicketNumber:
                cleanTicket,
            
            pickupTons:
                tonsValue,
            
            billingType:
                billingType,
            
            ratePerTon:
                ratePerTon,
            
            fuelSurchargePerTon:
                fuelSurchargePerTon,
            
            ratePerLoad:
                ratePerLoad,
            
            ratePerHour:
                ratePerHour
        )
        
        // ✅ Send admin notification to Supabase
        let notificationMessage: String

        if billingType == "per_load" {

            notificationMessage =
                "\(driver.name) picked up \(selectedPickupLocation) → \(selectedDropoffLocation) • \(displayTicket)"

        } else if billingType == "per_hour" {

            notificationMessage =
                "\(driver.name) picked up \(selectedPickupLocation) → \(selectedDropoffLocation) • \(displayTicket)"

        } else {

            notificationMessage =
                "\(driver.name) picked up \(selectedPickupLocation) → \(selectedDropoffLocation) • \(displayTicket) • \(tonsValue) tons"
        }

        sendAdminNotification(
            type: "Load Added",
            message: notificationMessage,
            ticket: cleanTicket
        )
        
        await MainActor.run {
            pickupTicket = ""
            pickupTons = ""
            dismiss()
        }
    }
}
