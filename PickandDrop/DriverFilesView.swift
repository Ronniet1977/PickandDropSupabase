//
//  DriverFilesView.swift
//  PickandDrop
//
//  Created by Ronald Thayer Jr on 5/20/26.
//

import SwiftUI
import UIKit
import Photos

enum AppTheme {

    static let cardBackground =
        Color.blue.opacity(0.12)

    static let accent =
        Color.blue

    static let success =
        Color.green

    static let warning =
        Color.orange
}

struct DriverFilesView: View {

    @State private var driverFolders: [URL] = []
    @State private var fuelEntries: [SupabaseFuel] = []

    var body: some View {

        NavigationStack {

            List {
                Section("Archives") {
                    
                    ShareLink(
                        item: archiveFileURL("Load_Archive.csv")
                    ) {
                        Label("Share Load Archive", systemImage: "shippingbox.fill")
                    }
                    
                    ShareLink(
                        item: archiveFileURL("Fuel_Archive.csv")
                    ) {
                        Label("Share Fuel Archive", systemImage: "fuelpump.fill")
                    }
                }
                
                Section("Admin Files") {
                    NavigationLink("Company Info") {
                        CompanyInfoCardView()
                    }

                    NavigationLink("Drivers") {
                        DriversCardView()
                    }
                    
                    NavigationLink {
                        AdminLoadManagementView()
                    } label: {
                        Label(
                            "Manage Loads",
                            systemImage: "shippingbox.and.arrow.backward.fill"
                        )
                    }

                    NavigationLink("Weekly Fuel") {
                        WeeklyFuelCardsView()
                    }

                    NavigationLink("Driver Sessions") {
                        DriverSessionsCardView()
                    }

                    NavigationLink {
                        FuelReportsView()
                    } label: {
                        Label(
                            "Fuel Reports",
                            systemImage: "fuelpump.fill"
                        )
                    }
                }
                .listRowBackground(AppTheme.cardBackground)

                ForEach(driverFolders, id: \.self) { folder in
                    NavigationLink {
                        DriverFolderDetailView(folder: folder)
                    } label: {
                        Label(folder.lastPathComponent, systemImage: "person.fill")
                    }
                    .listRowBackground(AppTheme.cardBackground)
                }
            }
            .scrollContentBackground(.hidden)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.08, green: 0.11, blue: 0.18),
                        Color(red: 0.15, green: 0.22, blue: 0.35),
                        Color.black.opacity(0.95)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .navigationTitle("Driver Files")
            .onAppear {
                Task {
                    fuelEntries =
                        await FuelSupabaseManager.shared
                            .fetchFuel()
                }
            }
        }
    }
    
    func archiveFileURL(_ fileName: String) -> URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PickandDrop")
            .appendingPathComponent("Archives")
            .appendingPathComponent(fileName)
    }

    func loadDriverFolders() {

        let driversFolder =
            StorageManager
                .truckReportsFolder()
                .appendingPathComponent("Drivers")

        do {

            driverFolders =
                try FileManager.default
                    .contentsOfDirectory(
                        at: driversFolder,
                        includingPropertiesForKeys: nil
                    )
                    .filter { $0.hasDirectoryPath }

        } catch {
            driverFolders = []
            print("📁 No old driver folders found")
        }
    }
}

struct DriverFolderDetailView: View {

    let folder: URL

    @State private var files: [URL] = []

    var body: some View {

        List {

            ForEach(files, id: \.self) { file in

                if file.hasDirectoryPath {

                    NavigationLink {

                        DriverSubfolderView(folder: file)

                    } label: {

                        Label(
                            file.lastPathComponent,
                            systemImage: "folder.fill"
                        )
                    }

                } else {

                    VStack(alignment: .leading) {

                        Text(file.lastPathComponent)
                            .font(.headline)

                        Text(file.path)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }        }
        .navigationTitle(folder.lastPathComponent)
        .onAppear {
            loadFiles()
        }
    }

    func loadFiles() {

        do {

            files =
                try FileManager.default
                    .contentsOfDirectory(
                        at: folder,
                        includingPropertiesForKeys: nil
                    )

        } catch {

            print(
                "❌ Failed loading files:",
                error
            )
        }
    }
}

struct DriverSubfolderView: View {

    let folder: URL

    @State private var files: [URL] = []

    var body: some View {

        List {

            ForEach(files, id: \.self) { file in

                if let image = UIImage(contentsOfFile: file.path) {

                    VStack(alignment: .leading, spacing: 10) {

                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 260)
                            .clipShape(RoundedRectangle(cornerRadius: 18))

                        Text(file.lastPathComponent)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)

                } else {

                    Text(file.lastPathComponent)
                }
            }
        }
        .navigationTitle(folder.lastPathComponent)
        .onAppear {
            loadFiles()
        }
    }

    func loadFiles() {

        do {

            files =
                try FileManager.default
                    .contentsOfDirectory(
                        at: folder,
                        includingPropertiesForKeys: nil
                    )

        } catch {

            print(
                "❌ Failed loading subfolder:",
                error
            )
        }
    }
}

struct FilePreviewView: View {

    let fileURL: URL

    @State private var text = ""

    var body: some View {
        ScrollView {
            Text(text)
                .font(.system(.caption, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .navigationTitle(fileURL.lastPathComponent)
        .onAppear {
            loadText()
        }
    }

    func loadText() {
        do {
            text = try String(contentsOf: fileURL, encoding: .utf8)
        } catch {
            text = "Could not read file:\n\(fileURL.lastPathComponent)"
        }
    }
}

//Cards
struct WeeklyFuelCardsView: View {

    @State private var fuelEntries: [SupabaseFuel] = []

    var totalFuel: Double {
        fuelEntries.reduce(0.0) {
            $0 + ($1.amount ?? 0)
        }
    }

    var body: some View {

        ScrollView {

            VStack(spacing: 16) {

                VStack(alignment: .leading, spacing: 8) {

                    Text("Weekly Fuel")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("$\(totalFuel, specifier: "%.2f")")
                        .font(.largeTitle.bold())

                    Text("\(fuelEntries.count) fuel entries")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Button {
                    Task {
                        await FuelReceiptManager.shared
                            .saveAllReceiptsToPhotos(
                                fuelEntries: fuelEntries
                            )

                        await FuelSupabaseManager.shared.deleteAllFuel()
                        
                        await MainActor.run {
                            fuelEntries = []
                        }
                    }
                } label: {
                    Label("Save All Receipts to Photos", systemImage: "square.and.arrow.down.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 24))

                ForEach(fuelEntries) { entry in

                    VStack(alignment: .leading, spacing: 10) {

                        HStack {

                            VStack(alignment: .leading, spacing: 4) {

                                Text(entry.driver_name ?? "Unknown")
                                    .font(.headline)

                                Text("Truck \(entry.truck_number ?? "")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                if let receiptPath = entry.receipt_path {

                                    SupabaseStorageImage(path: receiptPath)
                                        .frame(maxHeight: 220)
                                        .clipShape(
                                            RoundedRectangle(cornerRadius: 16)
                                        )

                                    Text("📸 Receipt Attached")
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                }
                            }

                            Spacer()

                            Text("$\(entry.amount ?? 0, specifier: "%.2f")")
                                .font(.title3.bold())
                                .foregroundStyle(AppTheme.success)
                        }

                        Text(entry.created_at ?? "")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                }
            }
            .padding()
        }
        .navigationTitle("Weekly Fuel")
        .onAppear {
            Task {
                let loaded =
                    await FuelSupabaseManager
                        .shared
                        .fetchFuel()

                await MainActor.run {
                    fuelEntries = loaded
                }
            }
        }
    }
}

struct CompanySettingsDTO: Codable {

    let truckingCompanyName: String
    let pickupCompanyName: String
    let dropoffCompanyName: String
    let companyJoinCode: String
    let ratePerTon: Double
}

struct CompanyInfoCardView: View {
    
    @State private var settings: SupabaseCompanySettings?
    @State private var showEditSheet = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                
                if let settings {
                    
                    VStack(alignment: .leading, spacing: 14) {
                        Text(settings.trucking_company_name)
                            .font(.largeTitle.bold())
                        
                        Label(
                            settings.pickup_company_name,
                            systemImage: "arrow.up.circle.fill"
                        )
                        
                        Label(
                            settings.dropoff_company_name,
                            systemImage: "arrow.down.circle.fill"
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Join Company Code")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text(settings.company_join_code)
                            .font(.title2.bold())
                            .foregroundStyle(AppTheme.accent)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.blue.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Rate Per Ton")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text("$\(settings.rate_per_ton, specifier: "%.2f")")
                            .font(.title2.bold())
                            .foregroundStyle(AppTheme.success)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.green.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    
                    Button {
                        showEditSheet = true
                    } label: {
                        Label(
                            "Edit Company Info",
                            systemImage: "pencil.circle.fill"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    
                } else {
                    ProgressView("Loading company info...")
                }
            }
            .padding()
        }
        .navigationTitle("Company Info")
        .task {
            await loadCompanyInfo()
        }
        .sheet(isPresented: $showEditSheet) {
            if let settings {
                NavigationStack {
                    EditCompanyInfoView(
                        settings: settings,
                        onSaved: {
                            Task {
                                await loadCompanyInfo()
                            }
                        }
                    )
                }
            }
        }
    }
    
    @MainActor
    func loadCompanyInfo() async {
        settings =
        await CompanySupabaseManager
            .shared
            .fetchCompanySettings()
    }
}

struct DriversCardView: View {

    @State private var drivers: [SupabaseDriver] = []

    var body: some View {

        ScrollView {

            VStack(spacing: 16) {

                ForEach(drivers, id: \.id) { driver in

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

                            Text(driver.role.uppercased())
                                .font(.caption.bold())
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    driver.role == "admin"
                                    ? Color.blue.opacity(0.15)
                                    : Color.green.opacity(0.15)
                                )
                                .foregroundStyle(
                                    driver.role == "admin"
                                    ? .blue
                                    : .green
                                )
                                .clipShape(Capsule())
                        }

                        HStack {

                            Label(
                                driver.username,
                                systemImage: "person.fill"
                            )

                            Spacer()

                            Label(
                                driver.is_active
                                ? "Active"
                                : "Inactive",
                                systemImage:
                                    driver.is_active
                                    ? "checkmark.circle.fill"
                                    : "xmark.circle.fill"
                            )
                            .foregroundStyle(
                                driver.is_active
                                ? .green
                                : .red
                            )
                        }
                        .font(.caption)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                }
            }
            .padding()
        }
        .navigationTitle("Drivers")
        .onAppear {
            loadDrivers()
        }
    }

    func loadDrivers() {
        Task {
            let loaded =
                await DriverSupabaseManager
                    .shared
                    .fetchDrivers()

            await MainActor.run {
                drivers = loaded
            }
        }
    }
}

struct DriverSessionsDTO: Codable {
    let sessions: [DriverSessionDTO]
}

struct DriverSessionDTO: Codable, Identifiable {

    var id: UUID { UUID() }

    let loginTime: Double
    let username: String
    let deviceName: String
}

struct DriverSessionsCardView: View {

    @State private var sessions: [DriverSessionDTO] = []

    var body: some View {

        ScrollView {

            VStack(spacing: 16) {

                ForEach(sessions.indices, id: \.self) { index in

                    let session = sessions[index]

                    VStack(alignment: .leading, spacing: 12) {

                        HStack {

                            VStack(alignment: .leading, spacing: 4) {

                                Text(session.username.capitalized)
                                    .font(.title3.bold())

                                Text(session.deviceName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "ipad.and.iphone")
                                .font(.title2)
                                .foregroundStyle(AppTheme.accent)
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 4) {

                            Text("Login Time")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text(
                                Date(timeIntervalSinceReferenceDate: session.loginTime)
                                    .formatted(
                                        date: .abbreviated,
                                        time: .shortened
                                    )
                            )
                            .font(.headline)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                }
            }
            .padding()
        }
        .navigationTitle("Driver Sessions")
        .onAppear {
            loadSessions()
        }
    }

    func loadSessions() {

        let url = StorageManager.truckReportsFolder()
            .appendingPathComponent("DriverSessions.json")

        do {

            let data = try Data(contentsOf: url)

            let decoded = try JSONDecoder()
                .decode(DriverSessionsDTO.self, from: data)

            sessions = decoded.sessions

        } catch {

            print("❌ Failed loading sessions:", error)
        }
    }
}

//AdminLoadManagementView
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

//EditCompanyInfoView
struct EditCompanyInfoView: View {
    
    let settings: SupabaseCompanySettings
    var onSaved: (() -> Void)? = nil
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var truckingCompanyName = ""
    @State private var pickupCompanyName = ""
    @State private var dropoffCompanyName = ""
    @State private var companyJoinCode = ""
    @State private var ratePerTon = ""
    
    @State private var isSaving = false
    
    var body: some View {
        Form {
            
            Section("Company") {
                TextField(
                    "Trucking Company Name",
                    text: $truckingCompanyName
                )
            }
            
            Section("Route") {
                TextField(
                    "Pickup Company",
                    text: $pickupCompanyName
                )
                
                TextField(
                    "Dropoff Company",
                    text: $dropoffCompanyName
                )
            }
            
            Section("Company Access") {
                TextField(
                    "Join Company Code",
                    text: $companyJoinCode
                )
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
            }
            
            Section("Billing") {
                TextField(
                    "Rate Per Ton",
                    text: $ratePerTon
                )
                .keyboardType(.decimalPad)
            }
            
            Button {
                Task {
                    await saveSettings()
                }
            } label: {
                Label(
                    isSaving ? "Saving..." : "Save Changes",
                    systemImage: "checkmark.circle.fill"
                )
            }
            .disabled(!isValid || isSaving)
        }
        .navigationTitle("Edit Company Info")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
        .onAppear {
            truckingCompanyName =
            settings.trucking_company_name
            
            pickupCompanyName =
            settings.pickup_company_name
            
            dropoffCompanyName =
            settings.dropoff_company_name
            
            companyJoinCode =
            settings.company_join_code
            
            ratePerTon =
            String(
                format: "%.2f",
                settings.rate_per_ton
            )
        }
    }
    
    private var isValid: Bool {
        !truckingCompanyName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty &&
        !pickupCompanyName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty &&
        !dropoffCompanyName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty &&
        (Double(ratePerTon) ?? -1) >= 0
    }
    
    private func saveSettings() async {
        
        guard !isSaving else {
            return
        }
        
        guard let rate = Double(ratePerTon) else {
            return
        }
        
        await MainActor.run {
            isSaving = true
        }
        
        await CompanySupabaseManager.shared.updateCompanySettings(
            id: settings.id,
            truckingCompanyName:
                truckingCompanyName.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ),
            pickupCompanyName:
                pickupCompanyName.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ),
            dropoffCompanyName:
                dropoffCompanyName.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ),
            companyJoinCode:
                companyJoinCode.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ),
            ratePerTon: rate
        )
        
        await MainActor.run {
            onSaved?()
            dismiss()
        }
    }
}
