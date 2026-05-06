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
    @Query var drivers: [DriverProfile]
    @Query var loads: [LoadItem]
    @Query var shifts: [Shift]
    @Query(sort: \LoadItem.createdAt, order: .reverse)
    var allLoads: [LoadItem]
    
    @AppStorage("hasSetup") var hasSetup = true
    @AppStorage("currentDriverName") var currentDriverName: String = ""
    
    @State private var selectedLoad: LoadItem?
    @State private var selectedDriver: DriverSummary?
    @State private var exportURL: URL?
    @State private var showImporter = false
    
    @State private var lastDeliveredCount: Int = 0
    
    @State private var timer = Timer.publish(every: 5, on: .main, in: .common)
        .autoconnect()
    @State private var lastUpdated: Date = Date()
    @State private var isRefreshing = false
    
    @State private var selectedFilter: AdminLoadFilter = .all
    
    @State private var showBossReport = false
    @State private var bossReportText = ""
    
    var combinedReports: [DriverSummary] {

        let grouped = Dictionary(grouping: allLoads) {
            $0.driverName
        }

        return grouped.map { (driverName, loads) in

            let driverProfile = drivers.first {
                $0.name == driverName
            }

            let shift = shifts.first {
                $0.driverName == driverName
            }

            return DriverSummary(
                name: driverName,
                truck: driverProfile?.truckNumber ?? "Unknown",

                loads: loads.count,

                pickupTons: loads.reduce(0.0) {
                    $0 + $1.pickupTons
                },

                deliveryTons: loads.reduce(0.0) {
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
                
                dict[load.driverName] = DriverSummary(
                    name: load.driverName,
                    truck: "N/A",

                    loads: 0,

                    pickupTons: 0,
                    deliveryTons: 0,

                    fuel: 0,
                    status: "unknown",

                    isFinished: false
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
            
            return DriverSummary(
                name: driverName,
                truck: driverProfile?.truckNumber ?? "—",
                loads: loads.count,

                pickupTons: loads.reduce(0.0) {
                    $0 + $1.pickupTons
                },

                deliveryTons: loads.reduce(0.0) {
                    $0 + $1.deliveryTons
                },

                fuel: 0,
                status: "active",
                
                isFinished: false
            )
        }
        .sorted { $0.name < $1.name }
    }
    
    //Boss Sumary
    var deliveredLoads: Int {
        allLoads.filter { $0.deliveredAt != nil }.count
    }
    
    var openLoads: Int {
        allLoads.filter { $0.pickedUpAt == nil }.count
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
        NavigationStack {
            ZStack {
                // 🔥 BACKGROUND
                LinearGradient(
                    colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
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
                                    title: "Open",
                                    value: "\(openLoads)",
                                    subtitle: "Not delivered",
                                    systemImage: "clock.fill"
                                )
                            }
                            
                            HStack(spacing: 12) {
                                BossSummaryCard(
                                    title: "BRC Tons",
                                    value: String(format: "%.0f", totalPickupTons),
                                    subtitle: "Pickup tons",
                                    systemImage: "arrow.up.circle.fill"
                                )
                                
                                BossSummaryCard(
                                    title: "HoneyGo Tons",
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
                            .padding(.vertical, 4)
                        }
                        
                        // 🔥 SUMMARY CARD
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Drivers")
                                    .font(.caption)
                                Text("\(filteredDriverSummaries.count)")
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
                        
                        
                        // 🔥 DRIVER CARDS
                        ForEach(filteredDriverSummaries) { driver in
                            driverCard(driver)
                        }
                    }
                    .padding()
                }
                .refreshable {
                    loadFromiCloud()
                }
            }
            .navigationTitle("Admin")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        bossReportText = makeBossDailyReport()
                        showBossReport = true
                    } label: {
                        Label("Boss Daily Report", systemImage: "doc.text.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button {
                        exportURL = exportBossDailyReport()
                    } label: {
                        Image(systemName: "doc.text.fill")
                    }
                    
                    Button {
                        showImporter = true
                    } label: {
                        Image(systemName: "tray.and.arrow.down")
                    }
                    
                    Button {
                        exportURL = exportCombinedCSV()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    
                    Button {
                        loadFromiCloud()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    
                    Button("Log Out") {
                        logout()
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
            .onAppear {
                requestNotificationPermission()
                loadFromiCloud()
                try? context.save()
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
                    ScrollView {
                        Text(bossReportText)
                            .font(.system(.body, design: .monospaced))
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .navigationTitle("Boss Daily Report")
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            ShareLink(item: bossReportText) {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                        }
                    }
                }
            }
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

                    Button(role: .destructive) {

                        deleteDriverActiveFile(driver)

                    } label: {

                        Image(systemName: "trash")
                    }
                }
            }
            
            Divider()
            
            HStack {
                
                Label("\(driver.loads)", systemImage: "shippingbox.fill")
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    
                    Text("Pickup: \(driver.pickupTons, specifier: "%.0f")")
                    
                    Text("Delivered: \(driver.deliveryTons, specifier: "%.0f")")
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
        .background(hasMismatch ? Color.red.opacity(0.15) : Color(.systemGray6).opacity(0.25))
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

        let fileName =
            "\(safeName)-Truck\(driver.truck)-ACTIVE.csv"

        let url = StorageManager
            .truckReportsFolder()
            .appendingPathComponent(fileName)

        do {

            if FileManager.default.fileExists(atPath: url.path) {

                try FileManager.default.removeItem(at: url)

                print("🧹 Deleted:", fileName)

                loadFromiCloud()
            }

        } catch {

            print("❌ Delete failed:", error)
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
    📋 BOSS DAILY REPORT
    Date: \(dateText)
    
    TOTALS
    Loads: \(totalLoads)
    Pickup Tons: \(String(format: "%.2f", totalPickupTons))
    Delivery Tons: \(String(format: "%.2f", totalDeliveryTons))
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
    Pickup Tons: \(String(format: "%.2f", driver.pickupTons))
    Delivered Tons: \(String(format: "%.2f", driver.deliveryTons))
    
    """
            
            for load in driverLoads {
                report += """
      • Ticket: \(load.pickupTicketNumber)
        Pickup Tons: \(String(format: "%.2f", load.pickupTons))
        Delivery Tons: \(String(format: "%.2f", load.deliveryTons))
    
    """
            }
            
            report += "-------------------------\n\n"
        }
        
        return report
    }
    
    func exportBossDailyReport() -> URL {
        var csv = "Driver,Truck,Loads,Pickup Tons,Delivery Tons,Open Loads,Delivered Loads,Difference\n"
        
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
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
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
        currentDriverName = ""   // if using AppStorage
        
        hasSetup = false
        selectedDriver = nil
        
        print("Logged out")
    }
    // 🔥 IMPORT
    func importCSVs(urls: [URL]) async {
        var summaryDict: [String: DriverSummary] = [:]
        
        for url in urls {
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
                            status: "unknown",
                            
                            isFinished: false
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

                    if pickedUpString != "Not picked up" {
                        newLoad.pickedUpAt = Date()
                    }

                    if !deliveredString.isEmpty {
                        newLoad.deliveredAt = Date()
                    }

                    summaryDict[driverName]?.fuel = Double(fuel) ?? 0

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

        let url = FileManager.default
            .temporaryDirectory
            .appendingPathComponent("Report.csv")

        try? csv.write(to: url, atomically: true, encoding: .utf8)

        return url
    }
    
    func loadFromiCloud() {
        
        if isRefreshing { return }   // ✅ prevents overlapping refreshes
        
        isRefreshing = true
        
        Task {
            
            let baseURL = StorageManager.truckReportsFolder()
            
            print("📂 Truck Reports base:", baseURL)
            
            do {
                let files = try FileManager.default.contentsOfDirectory(
                    at: baseURL,
                    includingPropertiesForKeys: nil
                )
                
                print("📄 Found files:", files.map { $0.lastPathComponent })
                
                var summaryDict: [String: DriverSummary] = [:]
                
                for file in files {
                    
                    let fileName = file.lastPathComponent
                    
                    // ✅ Only read driver ACTIVE files
                    // ❌ Skip ADMIN-ACTIVE.csv so it does not duplicate everything
                    if fileName == "ADMIN-ACTIVE.csv" { continue }
                    if !fileName.hasSuffix("-ACTIVE.csv") { continue }
                    
                    let text = try String(contentsOf: file, encoding: .utf8)
                    let rows = text.components(separatedBy: "\n").dropFirst()
                    
                    for row in rows where !row.trimmingCharacters(in: .whitespaces).isEmpty {
                        
                        let columns = row.components(separatedBy: ",")
                        if columns.count < 11 { continue }
                        
                        let driverName = columns[2].cleanedCSV()
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
                                status: "unknown",
                                
                                isFinished: false
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

                        if pickedUpString != "Not picked up" {
                            newLoad.pickedUpAt = Date()
                        }

                        if !deliveredString.isEmpty {
                            newLoad.deliveredAt = Date()
                        }

                        summaryDict[driverName]?.fuel = Double(fuel) ?? 0

                        context.insert(newLoad)
                    }
                }
                
                // 🔥 Move CSV write OFF main thread too
                DispatchQueue.global(qos: .background).async {
                    generateAdminActiveCSV(from: allLoads)
                }
                
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
                    isRefreshing = false
                }
                
            } catch {
                print("❌ Error reading iCloud:", error)
                
                await MainActor.run {
                    isRefreshing = false
                }
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
                
                summaryDict[load.driverName] = DriverSummary(
                    name: load.driverName,
                    truck: driverProfile?.truckNumber ?? "—",
                    loads: 0,
                    
                    pickupTons: 0,
                    deliveryTons: 0,
                    
                    fuel: 0,
                    status: "active",
                    
                    isFinished: false
                )
            }
            
            summaryDict[load.driverName]?.loads += 1
            summaryDict[load.driverName]?.pickupTons += load.pickupTons
            summaryDict[load.driverName]?.deliveryTons += load.deliveryTons
        }
        
        let summaries = Array(summaryDict.values)
        
        // SUMMARY CSV
        csv += "Driver,Truck,Loads,Pickup Tons,Delivery Tons,Fuel,Status\n"
        
        for d in summaries {
            
            let pickupString = String(format: "%.2f", d.pickupTons)
            let deliveryString = String(format: "%.2f", d.deliveryTons)
            
            csv += "\(d.name),\(d.truck),\(d.loads),\(pickupString),\(deliveryString),\(d.fuel),\(d.status)\n"
        }
        
        csv += "\n\n"
        
        // LOAD DETAILS
        csv += "Date,Time,Driver,Truck,Pickup Ticket,Pickup Tons,Delivery Ticket,Delivery Tons\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        
        for load in loads {
            
            let date = dateFormatter.string(from: load.createdAt)
            let time = timeFormatter.string(from: load.createdAt)
            
            let pickupString = String(format: "%.2f", load.pickupTons)
            let deliveryString = String(format: "%.2f", load.deliveryTons)
            
            csv += "\(date),\(time),\(load.driverName),—,\(load.pickupTicketNumber),\(pickupString),\(load.deliveryTicketNumber),\(deliveryString)\n"
        }
        
        let fileName = "ADMIN-ACTIVE.csv"
        
        let folder = StorageManager.truckReportsFolder()
        let fileURL = folder.appendingPathComponent(fileName)
        
        do {
            
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
            }
            
            try csv.write(to: fileURL, atomically: true, encoding: .utf8)
            
            print("✅ ADMIN ACTIVE (LOCAL):", fileURL)
            
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
