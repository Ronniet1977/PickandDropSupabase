import SwiftUI
import SwiftData
import Combine
import UniformTypeIdentifiers
import UserNotifications

enum AdminLoadFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case pickedUp = "Picked Up"
    case delivered = "Delivered"
    case open = "Open"
    
    var id: String { rawValue }
    
    func title(count: Int) -> String {
        "\(rawValue) (\(count))"
    }
}

struct AdminDashboardView: View {
    @Environment(\.modelContext) private var context
    @StateObject private var notificationManager = NotificationSyncManager()
    @Query var drivers: [DriverProfile]
    @Query var loads: [LoadItem]
    @Query var shifts: [Shift]
    @Query(sort: \LoadItem.createdAt, order: .reverse)
    var allLoads: [LoadItem]
    @Query var companySettings: [CompanySettings]
    
    
    @AppStorage("hasSetup") var hasSetup = true
    @AppStorage("currentDriverName") var currentDriverName: String = ""
    @AppStorage("isLoggedIn")
    var isLoggedIn = false

    @AppStorage("mustChangePassword")
    var mustChangePassword = false
    
    @State private var selectedLoad: LoadItem?
    @State private var selectedDriver: DriverSummary?
    @State private var exportURL: URL?
    @State private var showImporter = false
    @State private var showFolderPicker = false
    
    @State private var lastDeliveredCount: Int = 0
    
    @State private var timer = Timer.publish(every: 5, on: .main, in: .common)
        .autoconnect()
    @State private var lastUpdated: Date = Date()
    @State private var isRefreshing = false
    @State private var lastRefresh = Date.distantPast
    
    @State private var selectedFilter: AdminLoadFilter = .all
    
    @State private var showBossReport = false
    @State private var bossReportText = ""
    @State private var dismissedDrivers: Set<String> = []
    
    @State private var showResetAlert = false
    @State private var fuelByDriver: [String: Double] = [:]
    
    
    
    
    
    var settings: CompanySettings? {
        companySettings.first
    }
    
    var combinedReports: [DriverSummary] {

        let grouped = Dictionary(grouping: allLoads) {
            $0.driverName
        }

        return grouped.map { (driverName, loads) in

            let driverProfile = drivers.first {
                $0.name == driverName
            }

            let shift = shifts
                .filter { $0.driverName == driverName }
                .sorted { $0.startedAt > $1.startedAt }
                .first
            
            
            let driverLoads = allLoads.filter {
                $0.driverName == driverName
            }

            return DriverSummary(
                name: driverName,
                truck: driverProfile?.truckNumber ?? "Unknown",

                loads: driverLoads.count,

                pickupTons: driverLoads.reduce(0.0) {
                    $0 + $1.pickupTons
                },

                deliveryTons: driverLoads.reduce(0.0) {
                    $0 + $1.deliveryTons
                },

                fuel: shift?.fuelTotal ?? 0,
                status: shift?.status ?? "unknown",

                isFinished: shift?.status == "finished"
            )
        }
    }
    
    var driverSummaries: [DriverSummary] {

        var dict: [String: DriverSummary] = [:]

        for load in allLoads {

            if dict[load.driverName] == nil {

                let driverProfile = drivers.first {
                    $0.name == load.driverName
                }

                let shift = shifts
                    .filter { $0.driverName == load.driverName }
                    .sorted { $0.startedAt > $1.startedAt }
                    .first
                
                let isFinished = shift?.status == "finished"
                let status = isFinished ? "finished" : "active"

                dict[load.driverName] = DriverSummary(
                    name: load.driverName,
                    truck: driverProfile?.truckNumber ?? "N/A",

                    loads: 0,

                    pickupTons: 0,
                    deliveryTons: 0,

                    fuel: shift?.fuelTotal ?? 0,
                    status: status,
                    isFinished: isFinished
                )
            }

            dict[load.driverName]?.loads += 1
            dict[load.driverName]?.pickupTons += load.pickupTons
            dict[load.driverName]?.deliveryTons += load.deliveryTons
        }

        return Array(dict.values)
    }
    
    var totalLoads: Int {
        filteredLoads.count
    }
    
    //Filter Tabs
    var filteredLoads: [LoadItem] {
        switch selectedFilter {
            
        case .all:
            return allLoads
            
        case .pickedUp:
            return allLoads.filter {
                $0.isPickedUp && !$0.isDelivered
            }
            
        case .delivered:
            return allLoads.filter {
                $0.isDelivered
            }
            
        case .open:
            return allLoads.filter {
                !$0.isPickedUp
            }
        }
    }
    
    var filteredDriverSummaries: [DriverSummary] {
        let grouped = Dictionary(grouping: filteredLoads) { $0.driverName }
        
        return grouped.map { driverName, loads in
            
            let driverProfile = drivers.first {
                $0.name == driverName
            }
            
            let shift = shifts
                .filter { $0.driverName == driverName }
                .sorted { $0.startedAt > $1.startedAt }
                .first
            

            let isFinished = shift?.status == "finished"
            let status = isFinished ? "finished" : "active"

            return DriverSummary(
                name: driverName,
                truck: driverProfile?.truckNumber ?? "—",
                loads: loads.count,
                pickupTons: loads.reduce(0.0) { $0 + $1.pickupTons },
                deliveryTons: loads.reduce(0.0) { $0 + $1.deliveryTons },
                fuel: fuelByDriver[driverName] ?? 0,
                status: status,
                isFinished: isFinished
            )
        }
        .sorted {
            if $0.isFinished != $1.isFinished {
                return !$0.isFinished
            }
            
            return $0.name < $1.name
        }
    }
    
    var visibleDriverSummaries: [DriverSummary] {
        filteredDriverSummaries.filter {
            !dismissedDrivers.contains($0.name)
        }
    }
    
    //Boss Sumary
    var deliveredLoads: Int {
        allLoads.filter { $0.deliveredAt != nil }.count
    }
    
    var openLoads: Int {
        allLoads.filter { $0.pickedUpAt == nil }.count
    }
    
    var totalFuel: Double {
        WeeklyFuelManager.totalFuel()
    }
    
    var totalPickupTons: Double {
        allLoads
            .filter { $0.isPickedUp }
            .reduce(0.0) { $0 + $1.pickupTons }
    }
    
    // 🔥 until you track real delivery tons separately:
    var totalDeliveryTons: Double {
        allLoads
            .filter { $0.deliveredAt != nil }
            .reduce(0.0) { $0 + $1.deliveryTons }
    }
    
    var tonsDifference: Double {
        totalPickupTons - totalDeliveryTons
    }
    
    var body: some View {

        TabView {

            dashboardTab
                .tabItem {
                    Label(
                        "Dashboard",
                        systemImage: "chart.bar.fill"
                    )
                }

            NavigationStack {

                DriverManagerView()

            }
            .tabItem {
                Label(
                    "Drivers",
                    systemImage: "person.3.fill"
                )
            }

            NavigationStack {

                ReportsView()

            }
            .tabItem {
                Label(
                    "Reports",
                    systemImage: "doc.text.fill"
                )
            }
            NavigationStack {
                DriverFilesView()
            }
            .tabItem {
                Label("Files", systemImage: "folder.fill")
            }
            NavigationStack {
                HelpView()
            }
            .tabItem {
                Label("Help", systemImage: "questionmark.circle.fill")
            }
        }
    }
    var dashboardTab: some View {

        NavigationStack {
            ZStack {
                // 🔥 BACKGROUND
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.08, blue: 0.16),
                        Color(red: 0.10, green: 0.16, blue: 0.28),
                        Color.black
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        
                        // 🔥 HEADER
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Dashboard")
                                .font(.largeTitle.bold())
                            
                            Text("Driver Overview")
                                .foregroundStyle(.secondary)
                            
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        
                        VStack(spacing: 6) {
                            HStack(spacing: 8) {
                                
                                if isRefreshing {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Circle()
                                        .fill(.green)
                                        .frame(width: 8, height: 8)
                                        .scaleEffect(isRefreshing ? 1.3 : 1)
                                        .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: isRefreshing)
                                }
                                
                                Text(isRefreshing ? "Updating..." : "Live")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.bottom, 4)
                            
                            Text("Updated \(relativeTimeString(from: lastUpdated))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)
                        
                        if !notificationManager.notifications.isEmpty {

                            VStack(alignment: .leading, spacing: 12) {

                                HStack {
                                    Text("Driver Notifications")
                                        .font(.headline)

                                    Spacer()

                                    Text("\(notificationManager.notifications.count)")
                                        .font(.caption.bold())
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(.red)
                                        .foregroundStyle(.white)
                                        .clipShape(Capsule())
                                }

                                ForEach(notificationManager.notifications) { note in

                                    VStack(alignment: .leading, spacing: 6) {

                                        HStack {
                                            Text(note.type)
                                                .font(.caption.bold())
                                                .padding(6)
                                                .background(.green.opacity(0.2))
                                                .clipShape(Capsule())

                                            Spacer()

                                            Text(
                                                note.createdAt.formatted(
                                                    date: .omitted,
                                                    time: .shortened
                                                )
                                            )
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        }

                                        Text(note.message)
                                            .font(.body)

                                        HStack {
                                            Text("Driver: \(note.driverName)")
                                            Spacer()
                                            Text("Truck: \(note.truckNumber)")
                                        }
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                        Button(role: .destructive) {

                                            notificationManager.deleteNotification(note)

                                        } label: {

                                            Label(
                                                "Clear Notification",
                                                systemImage: "trash"
                                            )
                                        }
                                        .font(.caption)
                                    }
                                    .padding()
                                    .background(.thinMaterial)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                }
                            }
                            .padding()
                        }
                        
                        //Boss Summary Cards
                        VStack(spacing: 12) {
                            HStack(spacing: 12) {
                                BossSummaryCard(
                                    title: "Total Loads",
                                    value: "\(totalLoads)",
                                    subtitle: "\(deliveredLoads) delivered",
                                    systemImage: "shippingbox.fill"
                                )
                                
                                BossSummaryCard(
                                    title: "Fuel",
                                    value: "$\(String(format: "%.0f", totalFuel))",
                                    subtitle: "Shift fuel",
                                    systemImage: "fuelpump.fill"
                                )
                                
                                BossSummaryCard(
                                    title: "Open",
                                    value: "\(openLoads)",
                                    subtitle: "Not delivered",
                                    systemImage: "clock.fill"
                                )
                            }
                            
                            HStack(spacing: 12) {
                                BossSummaryCard(
                                    title: "\(settings?.pickupCompanyName ?? "Pickup") Tons",
                                    value: String(format: "%.0f", totalPickupTons),
                                    subtitle: "Pickup tons",
                                    systemImage: "arrow.up.circle.fill"
                                )
                                
                                BossSummaryCard(
                                    title: "\(settings?.dropoffCompanyName ?? "Drop Off") Tons",
                                    value: String(format: "%.0f", totalDeliveryTons),
                                    subtitle: "Delivery tons",
                                    systemImage: "arrow.down.circle.fill"
                                )
                            }
                            
                            BossSummaryCard(
                                title: "Difference",
                                value: String(format: "%.0f", tonsDifference),
                                subtitle: tonsDifference == 0 ? "Balanced" : "Check pickup vs delivery",
                                systemImage: tonsDifference == 0 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                            )
                            .foregroundStyle(
                                tonsDifference == 0 ? .green :
                                    abs(tonsDifference) < 5 ? .yellow :
                                        .red
                            )
                            
                            Picker("Filter", selection: $selectedFilter) {
                                ForEach(AdminLoadFilter.allCases) { filter in
                                    Text(filter.title(count: count(for: filter)))
                                        .tag(filter)
                                }
                            }
                            .pickerStyle(.segmented)
                            .animation(.spring(duration: 0.35), value: filteredLoads.count)
                            .padding(.vertical, 4)
                        }
                        
                        // 🔥 SUMMARY CARD
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Drivers")
                                    .font(.caption)
                                Text("\(visibleDriverSummaries.count)")
                                    .font(.title.bold())
                                Text("\(filteredLoads.count) loads shown")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing) {
                                Text("Loads")
                                    .font(.caption)
                                Text("\(totalLoads)")
                                    .font(.title.bold())
                            }
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .animation(.spring(duration: 0.35), value: filteredLoads.count)
                        
                        
                        // 🔥 DRIVER CARDS
                        ForEach(visibleDriverSummaries) { driver in
                            driverCard(driver)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Admin")
            .toolbar {

                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Boss Report") {

                        bossReportText = makeBossDailyReport()
                        showBossReport = true
                    }
                    .foregroundStyle(.white)

                    Button {
                        loadFromiCloud()
                        notificationManager.loadNotifications()
                    } label: {
                        if isRefreshing {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .disabled(isRefreshing)

                    Menu {
                        Button("Reset Shared Folder") {
                            UserDefaults.standard.removeObject(
                                forKey: StorageManager.folderBookmarkKey
                            )

                            print("🧹 Shared folder bookmark cleared")

                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                showFolderPicker = true
                            }
                        }

                        Button {
                            showImporter = true
                        } label: {
                            Label(
                                "Import CSV",
                                systemImage: "tray.and.arrow.down"
                            )
                        }

                        Divider()

                        Button(role: .destructive) {
                            showResetAlert = true
                        } label: {
                            Label(
                                "Archive & Reset",
                                systemImage: "trash.fill"
                            )
                        }

                        Divider()

                        Button(role: .destructive) {
                            logout()
                        } label: {
                            Label(
                                "Log Out",
                                systemImage: "rectangle.portrait.and.arrow.right"
                            )
                        }

                    } label: {

                        Image(systemName: "ellipsis.circle.fill")
                    }
                }
            }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.commaSeparatedText],
                allowsMultipleSelection: true
            ) { result in
                if case let .success(urls) = result {
                    Task { await importCSVs(urls: urls) }
                }
            }
            .onReceive(
                Timer.publish(
                    every: 60,
                    on: .main,
                    in: .common
                ).autoconnect()
            ) { _ in

                guard !isRefreshing else { return }

                guard Date().timeIntervalSince(lastRefresh) > 45 else {
                    return
                }

                lastRefresh = Date()

                loadFromiCloud()
                notificationManager.loadNotifications()
            }
            .onAppear {
                requestNotificationPermission()
                loadFromiCloud()

                notificationManager.loadNotifications()
            }
            .sheet(item: $selectedDriver) { driver in
                DriverDetailView(
                    driver: driver,
                    loads: allLoads
                        .filter { $0.driverName == driver.name }
                        .sorted { $0.createdAt > $1.createdAt }
                )
            }
            .sheet(isPresented: Binding(
                get: { exportURL != nil },
                set: { if !$0 { exportURL = nil } }
            )) {
                if let url = exportURL {
                    ShareSheet(items: [url])
                }
            }
            .sheet(isPresented: $showBossReport) {

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

                            VStack(alignment: .leading, spacing: 20) {

                                Text("Boss Daily Report")
                                    .font(.largeTitle.bold())
                                    .foregroundStyle(.white)

                                Text(bossReportText)
                                    .font(.body.monospaced())
                                    .foregroundStyle(.white.opacity(0.9))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding()
                                    .background(.ultraThinMaterial)
                                    .clipShape(RoundedRectangle(cornerRadius: 24))
                            }
                            .padding()
                        }
                    }
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {

                        ToolbarItem(placement: .topBarTrailing) {

                            Button("Done") {
                                showBossReport = false
                            }
                            .foregroundStyle(.white)
                        }

                        ToolbarItem(placement: .topBarLeading) {

                            ShareLink(item: bossReportText) {

                                Image(systemName: "square.and.arrow.up")
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                }
            }
            .fileImporter(
                isPresented: $showFolderPicker,
                allowedContentTypes: [.folder]
            ) { result in

                switch result {

                case .success(let url):

                    StorageManager.saveTruckReportsFolder(url)

                    print("✅ New shared folder selected")

                case .failure(let error):

                    print("❌ Folder picker failed:", error)
                }
            }
            .alert(
                "Archive & Reset?",
                isPresented: $showResetAlert
            ) {

                Button("Cancel", role: .cancel) { }

                Button("Reset", role: .destructive) {
                    archiveAndReset()
                }

            } message: {

                Text(
                    "This will clear active loads and shifts but keep FINAL reports."
                )
            }
        }
    }
    
    func openDriversFolder() {

        let folder = StorageManager
            .truckReportsFolder()
            .appendingPathComponent("Drivers")

        try? FileManager.default.createDirectory(
            at: folder,
            withIntermediateDirectories: true
        )

        UIApplication.shared.open(folder)
    }
    
    func archiveAndReset() {

        print("🔥 RESET BUTTON PRESSED")

        do {

            let loadCount = loads.count
            let shiftCount = shifts.count

            print("Loads:", loadCount)
            print("Shifts:", shiftCount)

            try context.delete(model: LoadItem.self)
            try context.delete(model: Shift.self)

            try context.save()

            print("✅ SwiftData deleted")

            // DELETE ACTIVE CSV FILES
            let reportsFolder =
                StorageManager.truckReportsFolder()

            let files = try FileManager.default.contentsOfDirectory(
                at: reportsFolder,
                includingPropertiesForKeys: nil
            )

            for file in files {

                print("📄 Found file:", file.lastPathComponent)

                if file.lastPathComponent
                    .hasSuffix("-ACTIVE.csv")
                    ||
                    file.lastPathComponent
                    == "ADMIN-ACTIVE.csv" {

                    try? FileManager.default.removeItem(at: file)

                    print("🗑 Deleted ACTIVE file")
                }
            }

            print("✅ Archive & Reset complete")

        } catch {

            print("❌ Reset failed:", error)
        }
    }
    
    func driverCard(_ driver: DriverSummary) -> some View {
        let deliveredTons = allLoads
            .filter {
                $0.driverName == driver.name &&
                $0.deliveredAt != nil
            }
            .reduce(0.0) { $0 + $1.deliveryTons }
        
        let hasMismatch = deliveredTons > 0 && abs(driver.pickupTons - driver.deliveryTons) > 0.01
        
        return VStack(alignment: .leading, spacing: 10) {
            HStack {

                VStack(alignment: .leading, spacing: 4) {

                    Text(driver.name)
                        .font(.headline)

                    if driver.isFinished {

                        Text("✅ Finished")
                            .font(.caption)
                            .foregroundStyle(.green)

                    } else {

                        Text("🟢 Active")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                }

                Spacer()

                HStack(spacing: 12) {

                    Text("Truck \(driver.truck)")
                        .font(.caption)
                        .padding(6)
                        .background(.gray.opacity(0.2))
                        .clipShape(Capsule())

                    if driver.isFinished {

                        Button(role: .destructive) {

                            dismissedDrivers.insert(driver.name)

                        } label: {

                            Image(systemName: "trash")
                        }
                    }
                }
            }
            
            Divider()
            
            HStack {
                
                Label("\(driver.loads)", systemImage: "shippingbox.fill")
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    
                    Text(
                        "\(settings?.pickupCompanyName ?? "Pickup"): \(driver.pickupTons, specifier: "%.0f")"
                    )
                    
                    Text(
                        "\(settings?.dropoffCompanyName ?? "Dropoff"): \(driver.deliveryTons, specifier: "%.0f")"
                    )
                    
                    Text(
                        "Fuel: $\(WeeklyFuelManager.fuelForDriver(driver.name), specifier: "%.0f")"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    
                }
                .font(.caption)
            }
            .foregroundStyle(.secondary)
            
            if hasMismatch {
                Text("⚠️ Pickup / delivery tons mismatch")
                    .font(.caption2.bold())
                    .foregroundStyle(.red)
            }
        }
        .padding()
        .background(
            hasMismatch
            ? Color.red.opacity(0.18)
            : Color.green.opacity(0.12)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        .onTapGesture {
            selectedDriver = driver
        }
    }
    
    func deleteDriverActiveFile(_ driver: DriverSummary) {

        let safeName = driver.name
            .replacingOccurrences(
                of: "[^a-zA-Z0-9_-]",
                with: "_",
                options: .regularExpression
            )

        let folder = StorageManager.truckReportsFolder()

        do {

            let files = try FileManager.default.contentsOfDirectory(
                at: folder,
                includingPropertiesForKeys: nil
            )

            for file in files {

                let name = file.lastPathComponent

                if name.contains(safeName)
                    && name.hasSuffix("-ACTIVE.csv") {

                    print("🔍 Looking for:", "\(safeName)-Truck\(driver.truck)-ACTIVE.csv")
                    print("📄 Checking:", name)

                    try FileManager.default.removeItem(at: file)

                    print("🗑 Deleted ACTIVE:", name)
                }
            }

        } catch {

            print("❌ Failed deleting ACTIVE file:", error)
        }
    }
    
    func relativeTimeString(from date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        
        if seconds < 5 { return "just now" }
        if seconds < 60 { return "\(seconds)s ago" }
        
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m ago" }
        
        return date.formatted(date: .omitted, time: .shortened)
    }
    
    func makeBossDailyReport() -> String {
        let dateText = Date().formatted(date: .abbreviated, time: .omitted)
        
        let totalLoads = driverSummaries.reduce(0) { $0 + $1.loads }
        let totalPickupTons = driverSummaries.reduce(0.0) {
            $0 + $1.pickupTons
        }
        let totalDeliveryTons = driverSummaries.reduce(0.0) {
            $0 + $1.deliveryTons
        }
        let totalFuel = driverSummaries.reduce(0.0) { $0 + $1.fuel }
        
        var report = """
    📋 \(settings?.truckingCompanyName ?? "Trucking Company") DAILY REPORT
    Date: \(dateText)
    
    TOTALS
    Loads: \(totalLoads)
    \(settings?.pickupCompanyName ?? "Pickup") Tons: \(String(format: "%.2f", totalPickupTons))
    \(settings?.dropoffCompanyName ?? "Dropoff") Tons: \(String(format: "%.2f", totalDeliveryTons))
    Fuel: \(String(format: "%.2f", totalFuel))
    
    -------------------------
    
    """
        
        for driver in driverSummaries.sorted(by: { $0.name < $1.name }) {
            
            let driverLoads = allLoads.filter {
                $0.driverName == driver.name
            }
            
            report += """
    👤 \(driver.name)
    Truck: \(driver.truck)
    Loads: \(driver.loads)
    \(settings?.pickupCompanyName ?? "Pickup") Tons: \(String(format: "%.2f", driver.pickupTons))
    \(settings?.dropoffCompanyName ?? "Dropoff") Tons: \(String(format: "%.2f", driver.deliveryTons))
    
    """
            
            for load in driverLoads {
                report += """
      • Ticket: \(load.pickupTicketNumber)
        \(settings?.pickupCompanyName ?? "Pickup") Tons: \(String(format: "%.2f", load.pickupTons))
        \(settings?.dropoffCompanyName ?? "Dropoff") Tons: \(String(format: "%.2f", load.deliveryTons))
    
    """
            }
            
            report += "-------------------------\n\n"
        }
        
        return report
    }
    
    func exportBossDailyReport() -> URL {
        var csv = "Driver,Truck,Loads,\(settings?.pickupCompanyName ?? "Pickup") Tons,\(settings?.dropoffCompanyName ?? "Dropoff") Tons,Open Loads,Delivered Loads,Difference\n"
        
        let grouped = Dictionary(grouping: allLoads) { $0.driverName }
        
        for (driverName, driverLoads) in grouped.sorted(by: { $0.key < $1.key }) {
            let driverProfile = drivers.first {
                $0.name == driverName
            }
            
            let truck = driverProfile?.truckNumber ?? "—"
            let loads = driverLoads.count
            
            let pickupTons = driverLoads.reduce(0.0) { $0 + $1.pickupTons }
            
            // 🔥 Until you add real delivery tons
            let deliveryTons = driverLoads.reduce(0.0) {
                $0 + $1.deliveryTons
            }
            
            let delivered = driverLoads.filter {
                $0.deliveredAt != nil
            }.count
            
            let open = loads - delivered
            
            let difference = pickupTons - deliveryTons
            
            let pickupString = String(format: "%.2f", pickupTons)
            let deliveryString = String(format: "%.2f", deliveryTons)
            let differenceString = String(format: "%.2f", difference)
            
            csv += "\(driverName),\(truck),\(loads),\(pickupString),\(deliveryString),\(open),\(delivered),\(differenceString)\n"
        }
        
        csv += "\n"
        
        // 🔥 TOTALS (aligned correctly)
        let totalDeliveryTons = allLoads
            .filter { $0.isDelivered }
            .reduce(0.0) { $0 + $1.deliveryTons }
        
        csv += "TOTALS,,\(totalLoads),\(totalPickupTons),\(totalDeliveryTons),\(openLoads),\(deliveredLoads),\(tonsDifference)\n"
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm"
        
        let fileName = "Boss-Daily-Report-\(formatter.string(from: Date())).csv"
        let url = StorageManager
            .truckReportsFolder()
            .appendingPathComponent(fileName)
        
        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
            print("✅ Boss report created:", url)
        } catch {
            print("❌ Boss report failed:", error)
        }
        
        return url
    }
    
    
    func count(for filter: AdminLoadFilter) -> Int {
        switch filter {
            
        case .all:
            return allLoads.count
            
        case .pickedUp:
            return allLoads.filter {
                $0.isPickedUp && !$0.isDelivered
            }.count
            
        case .delivered:
            return allLoads.filter {
                $0.isDelivered
            }.count
            
        case .open:
            return allLoads.filter {
                !$0.isPickedUp
            }.count
        }
    }
    
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
    
    func sendAdminNotification(message: String) {
        let content = UNMutableNotificationContent()
        content.title = "New Delivery 🚛"
        content.body = message
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    func logout() {

        currentDriverName = ""
        isLoggedIn = false
        mustChangePassword = false
    }
    // 🔥 IMPORT
    func importCSVs(urls: [URL]) async {
        var summaryDict: [String: DriverSummary] = [:]
        
        for url in urls {

            let fileName = url.lastPathComponent

            if !fileName.hasSuffix("-ACTIVE.csv") {
                continue
            }

            do {
                let text = try String(contentsOf: url, encoding: .utf8)
                let rows = text.components(separatedBy: "\n").dropFirst()
                
                for row in rows where !row.trimmingCharacters(in: .whitespaces).isEmpty {
                    let columns = row.components(separatedBy: ",")
                    if columns.count < 11 { continue }
                    
                    let driverName = columns[2].cleanedCSV()
                    let truck = columns[3].cleanedCSV()
                    
                    let pickupTicket = columns[4].cleanedCSV()
                    let pickupTons = Double(columns[5].trimmed()) ?? 0

                    let rawDeliveryTicket = columns[6].cleanedCSV()

                    let deliveryTicket =
                        rawDeliveryTicket == "Not delivered"
                        ? ""
                        : rawDeliveryTicket
                    let deliveryTons = Double(columns[7].trimmed()) ?? 0
                    
                    let pickedUpString = columns[8].trimmed()
                    let deliveredString = columns[9].trimmed()
                    let fuel = columns[10].trimmed()
                    
                    if summaryDict[driverName] == nil {

                        let shift = shifts
                            .filter { $0.driverName == driverName }
                            .sorted { $0.startedAt > $1.startedAt }
                            .first

                        let isFinished = shift?.status == "finished"

                        summaryDict[driverName] = DriverSummary(
                            name: driverName,
                            truck: truck,
                            loads: 0,

                            pickupTons: 0,
                            deliveryTons: 0,

                            fuel: 0,

                            status: isFinished ? "finished" : "active",

                            isFinished: isFinished
                        )
                    }
                    
                    summaryDict[driverName]?.loads += 1
                    summaryDict[driverName]?.pickupTons += pickupTons
                    summaryDict[driverName]?.deliveryTons += deliveryTons
                    
                    let newLoad = LoadItem()

                    newLoad.driverName = driverName
                    newLoad.pickupTicketNumber = pickupTicket
                    newLoad.pickupTons = pickupTons

                    newLoad.deliveryTicketNumber = deliveryTicket
                    newLoad.deliveryTons = deliveryTons

                    newLoad.createdAt = Date()

                    newLoad.status = "new"

                    if pickedUpString != "Not picked up" {
                        newLoad.pickedUpAt = Date()
                        newLoad.status = "pickedUp"
                    }

                    let cleanedDelivered = deliveredString
                        .trimmingCharacters(in: .whitespacesAndNewlines)

                    if !cleanedDelivered.isEmpty &&
                       cleanedDelivered != "0" &&
                       cleanedDelivered != "0.00" {

                        newLoad.deliveredAt = Date()
                        newLoad.status = "delivered"
                    }
                    
                    let fuelValue = Double(fuel) ?? 0

                    if fuelValue > 0 {
                        summaryDict[driverName]?.fuel = fuelValue
                    }

                    context.insert(newLoad)
                }
            } catch {
                print(error)
            }
        }
    }
    
    // 🔥 EXPORT
    func exportCombinedCSV() -> URL {

        var csv = "Driver,Truck,Loads,Pickup Tons,Delivery Tons\n"

        for d in combinedReports {

            let pickupString = String(format: "%.2f", d.pickupTons)
            let deliveryString = String(format: "%.2f", d.deliveryTons)

            csv += "\(d.name),\(d.truck),\(d.loads),\(pickupString),\(deliveryString)\n"
        }

        let url = StorageManager
            .truckReportsFolder()
            .appendingPathComponent("Report.csv")

        try? csv.write(to: url, atomically: true, encoding: .utf8)

        return url
    }
    
    func loadFromiCloud() {
        
        if isRefreshing {
            print("⛔️ Already refreshing")
            return
        }   // ✅ prevents overlapping refreshes
        
        isRefreshing = true
        
        var activeDriverNames: Set<String> = []
        
        Task {

            defer {
                Task { @MainActor in
                    isRefreshing = false
                }
            }

            let baseURL = StorageManager.truckReportsFolder()
            
            print("📂 Truck Reports base:", baseURL)
            
            do {
                let files = try FileManager.default.contentsOfDirectory(
                    at: baseURL,
                    includingPropertiesForKeys: nil
                )
                
                print("📄 Found files:", files.map { $0.lastPathComponent })
                
                for load in allLoads {
                    context.delete(load)
                }

                try? context.save()
                
                var summaryDict: [String: DriverSummary] = [:]
                
                for file in files {

                    let fileName = file.lastPathComponent

                    if fileName == "ADMIN-ACTIVE.csv" { continue }
                    if !fileName.hasSuffix("-ACTIVE.csv") { continue }

                    print("📄 IMPORTING:", file.lastPathComponent)
                    print("📍 Path:", file.path)
                    
                    let text = try String(contentsOf: file, encoding: .utf8)
                    let rows = text.components(separatedBy: "\n").dropFirst()
                    
                    for row in rows where !row.trimmingCharacters(in: .whitespaces).isEmpty {
                        
                        let columns = row.components(separatedBy: ",")
                        if columns.count < 11 { continue }
                        
                        let driverName = columns[2].cleanedCSV()
                        activeDriverNames.insert(driverName)
                        let truck = columns[3].cleanedCSV()
                        
                        let pickupTicket = columns[4].cleanedCSV()
                        let pickupTons = Double(columns[5].trimmed()) ?? 0

                        let deliveryTicket = columns[6].cleanedCSV()
                        let deliveryTons = Double(columns[7].trimmed()) ?? 0
                        
                        let pickedUpString = columns[8].trimmed()
                        let deliveredString = columns[9].trimmed()
                        let fuel = columns[10].trimmed()
                        
                        if summaryDict[driverName] == nil {
                            summaryDict[driverName] = DriverSummary(
                                name: driverName,
                                truck: truck,
                                loads: 0,

                                pickupTons: 0,
                                deliveryTons: 0,

                                fuel: 0,

                                status: "active",
                                isFinished: false
                            )
                        }
                        
                        summaryDict[driverName]?.loads += 1
                        summaryDict[driverName]?.pickupTons += pickupTons
                        summaryDict[driverName]?.deliveryTons += deliveryTons
                        
                        let dateString = columns[0].trimmed()
                        let timeString = columns[1].trimmed()

                        let combined =
                            "\(dateString) \(timeString)"

                        let formatter = DateFormatter()
                        formatter.dateFormat = "yyyy-MM-dd HH:mm"

                        let parsedDate =
                            formatter.date(from: combined)
                            ?? Date()
                        
                        
                        let newLoad = LoadItem()

                        newLoad.driverName = driverName
                        newLoad.pickupTicketNumber = pickupTicket
                        newLoad.pickupTons = pickupTons

                        newLoad.deliveryTicketNumber = deliveryTicket
                        newLoad.deliveryTons = deliveryTons

                        newLoad.createdAt = parsedDate

                        newLoad.status = "new"

                        if pickedUpString != "Not picked up" {
                            newLoad.pickedUpAt = Date()
                            newLoad.status = "pickedUp"
                        }

                        let cleanedDelivered = deliveredString
                            .trimmingCharacters(in: .whitespacesAndNewlines)

                        if !cleanedDelivered.isEmpty &&
                           cleanedDelivered != "0" &&
                           cleanedDelivered != "0.00" {

                            newLoad.deliveredAt = Date()
                            newLoad.status = "delivered"
                        }

                        let fuelValue = Double(fuel) ?? 0

                        if fuelValue > 0 {
                            summaryDict[driverName]?.fuel = fuelValue
                            
                            await MainActor.run {
                                fuelByDriver[driverName] = fuelValue
                            }
                        }

                        context.insert(newLoad)
                    }
                }
                
                // 🔥 Move CSV write OFF main thread too
                try? context.save()

                let refreshedLoads = try? context.fetch(
                    FetchDescriptor<LoadItem>()
                )

                generateAdminActiveCSV(
                    from: refreshedLoads ?? []
                )
                
                // ✅ UI update safely
                await MainActor.run {
                    
                    let deliveredCount = allLoads.filter {
                        $0.deliveredAt != nil
                    }.count
                    
                    if deliveredCount > lastDeliveredCount {
                        let newDeliveries = deliveredCount - lastDeliveredCount
                        
                        sendAdminNotification(
                            message: "\(newDeliveries) new delivery(s)"
                        )
                    }
                    
                    lastDeliveredCount = deliveredCount
                    
                    withAnimation {
                    }
                    
                    lastUpdated = Date()
                }
                
            } catch {
                print("❌ Error reading iCloud:", error)
            }
        }
    }
    
    
    func generateAdminActiveCSV(from loads: [LoadItem]) {
        
        var csv = "Last Updated,\(Date())\n\n"
        
        // SUMMARY
        var summaryDict: [String: DriverSummary] = [:]
        
        for load in loads {
            
            if summaryDict[load.driverName] == nil {

                let driverProfile = drivers.first {
                    $0.name == load.driverName
                }

                let shift = shifts
                    .filter { $0.driverName == load.driverName }
                    .sorted { $0.startedAt > $1.startedAt }
                    .first

                let isFinished = shift?.status == "finished"

                summaryDict[load.driverName] = DriverSummary(
                    name: load.driverName,
                    truck: driverProfile?.truckNumber ?? "—",
                    loads: 0,

                    pickupTons: 0,
                    deliveryTons: 0,

                    fuel: filteredDriverSummaries
                        .first { $0.name == load.driverName }?
                        .fuel ?? 0,

                    status: isFinished ? "finished" : "active",

                    isFinished: isFinished
                )
            }
            
            summaryDict[load.driverName]?.loads += 1
            summaryDict[load.driverName]?.pickupTons += load.pickupTons
            summaryDict[load.driverName]?.deliveryTons += load.deliveryTons
        }
        
        let summaries = Array(summaryDict.values)
        
        // SUMMARY CSV
        csv += "Driver,Truck,Loads,Pickup Tons,Delivery Tons,Status\n"
        
        for d in summaries {
            
            let pickupString = String(format: "%.2f", d.pickupTons)
            let deliveryString = String(format: "%.2f", d.deliveryTons)
            
            csv += "\(d.name),\(d.truck),\(d.loads),\(pickupString),\(deliveryString),\(d.status)\n"
        }
        
        csv += "\n\n"
        
        // LOAD DETAILS
        csv += "Date,Time,Driver,Truck,\(settings?.pickupCompanyName ?? "Pickup") Ticket,\(settings?.pickupCompanyName ?? "Pickup") Tons,\(settings?.dropoffCompanyName ?? "Dropoff") Ticket,\(settings?.dropoffCompanyName ?? "Dropoff") Tons\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        
        for load in loads {
            
            let date = dateFormatter.string(from: load.createdAt)
            let time = timeFormatter.string(from: load.createdAt)
            
            let pickupString = String(format: "%.2f", load.pickupTons)
            let deliveryString = String(format: "%.2f", load.deliveryTons)
            
            let deliveryTicket = load.isDelivered
                ? load.deliveryTicketNumber
                : "Not delivered"

            let deliveryOutput = load.isDelivered
                ? deliveryString
                : "Not delivered"

            csv += "\(date),\(time),\(load.driverName),—,\(load.pickupTicketNumber),\(pickupString),\(deliveryTicket),\(deliveryOutput)\n"
        }
        
        let fileName = "ADMIN-ACTIVE.csv"
        
        let folder = StorageManager.truckReportsFolder()
        let fileURL = folder.appendingPathComponent(fileName)
        
        do {
            if let oldText = try? String(contentsOf: fileURL, encoding: .utf8),
               oldText == csv {
                print("✅ ADMIN ACTIVE unchanged — skipping write")
                return
            }
            
            let data = Data(csv.utf8)

            try data.write(
                to: fileURL,
                options: .atomic
            )
            
            print("✅ ADMIN ACTIVE (SHARED):", fileURL)
            
        } catch {
            print("❌ Failed:", error)
        }
    }
}

//Boss Summary card
struct BossSummaryCard: View {
    let title: String
    let value: String
    let subtitle: String
    let systemImage: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: systemImage)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Text(value)
                .font(.title2.bold())
            
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}
