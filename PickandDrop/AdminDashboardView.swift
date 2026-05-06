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

    @AppStorage("hasSetup") var hasSetup = true
    @AppStorage("currentDriverName") var currentDriverName: String = ""
    
    @State private var allLoads: [ReportLoadItem] = []
    @State private var selectedLoad: ReportLoadItem?
    @State private var selectedDriver: DriverSummary?
    @State private var exportURL: URL?
    @State private var showImporter = false
    
    @State private var lastDeliveredCount: Int = 0
    
    @State private var timer = Timer.publish(every: 5, on: .main, in: .common)
        .autoconnect()
    @State private var lastUpdated: Date = Date()
    @State private var isRefreshing = false
    
    @State private var selectedFilter: AdminLoadFilter = .all
    
    var combinedReports: [DriverSummary] {
        let grouped = Dictionary(grouping: allLoads) { $0.driverName }
        
        return grouped.map { (driverName, driverLoads) in
            let totalTons = driverLoads.reduce(0.0) { $0 + $1.pickupTons }
            
            let shift = shifts.first(where: { $0.driverName == driverName })

            return DriverSummary(
                name: driverName,
                truck: driverLoads.first?.truck ?? "Unknown",
                loads: driverLoads.count,
                tons: totalTons,
                fuel: shift?.fuelTotal ?? 0,
                status: shift?.status ?? "unknown"
            )
        }
        .sorted { $0.name < $1.name }
    }
    
    var driverSummaries: [DriverSummary] {
        
        var dict: [String: DriverSummary] = [:]
        
        // Build from loads
        for load in allLoads {
            if dict[load.driverName] == nil {
                dict[load.driverName] = DriverSummary(
                    name: load.driverName,
                    truck: load.truck,
                    loads: 0,
                    tons: 0,
                    fuel: 0,
                    status: "unknown"
                )
            }
            
            dict[load.driverName]?.loads += 1
            dict[load.driverName]?.tons += load.pickupTons
        }
        
        // Merge in shift data (fuel + status)
        for shift in shifts {
            if dict[shift.driverName] != nil {
                dict[shift.driverName]?.fuel = shift.fuelTotal
                dict[shift.driverName]?.status = shift.status
            }
        }
        
        return Array(dict.values)
    }
    var totalLoads: Int {
        filteredLoads.count
    }
    
    //Filter Tabs
    var filteredLoads: [ReportLoadItem] {
        switch selectedFilter {
        case .all:
            return allLoads
        case .pickedUp:
            return allLoads.filter {
                $0.deliveryTicketNumber.isEmpty
            }
        case .delivered:
            return allLoads.filter {
                !$0.deliveryTicketNumber.isEmpty
            }
        case .open:
            return allLoads.filter {
                $0.deliveryTicketNumber.isEmpty
            }
        }
    }
    
    var filteredDriverSummaries: [DriverSummary] {
        let grouped = Dictionary(grouping: filteredLoads) { $0.driverName }
        
        return grouped.map { driverName, loads in
            DriverSummary(
                name: driverName,
                truck: loads.first?.truck ?? "Unknown",
                loads: loads.count,
                tons: loads.reduce(0.0) { $0 + $1.pickupTons },
                fuel: 0,
                status: "active"
            )
        }
        .sorted { $0.name < $1.name }
    }
    
    //Boss Sumary
    var deliveredLoads: Int {
        allLoads.filter { !$0.deliveryTicketNumber.isEmpty }.count
    }
    
    var openLoads: Int {
        allLoads.filter { $0.deliveryTicketNumber.isEmpty }.count
    }
    
    var totalPickupTons: Double {
        allLoads.reduce(0.0) { $0 + $1.pickupTons }
    }
    
    var totalDeliveryTons: Double {
        allLoads.reduce(0.0) { $0 + $1.deliveryTons }
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
                            
                            Text(StorageManager.truckReportsFolder().path)
                                .font(.caption2)
                                .foregroundStyle(.red)
                                .lineLimit(3)
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
            }
            .sheet(item: $selectedDriver) { driver in
                DriverDetailView(
                    driver: driver,
                    loads: allLoads
                        .filter { $0.driverName == driver.name }
                        .sorted { Int($0.pickupTicketNumber) ?? 0 > Int($1.pickupTicketNumber) ?? 0 }
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
        }
    }
    
    func driverCard(_ driver: DriverSummary) -> some View {
        let deliveredTons = allLoads
            .filter {
                $0.driverName == driver.name &&
                !$0.deliveryTicketNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            .reduce(0.0) { $0 + $1.deliveryTons }
        
        let hasMismatch = deliveredTons > 0 && abs(driver.tons - deliveredTons) > 0.01
        
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(driver.name)
                    .font(.headline)
                
                Spacer()
                
                Text("Truck \(driver.truck)")
                    .font(.caption)
                    .padding(6)
                    .background(.gray.opacity(0.2))
                    .clipShape(Capsule())
            }
            
            Divider()
            
            HStack {
                Label("\(driver.loads)", systemImage: "shippingbox.fill")
                Spacer()
                Label("\(driver.tons, specifier: "%.0f") tons", systemImage: "scalemass.fill")
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
    
    func relativeTimeString(from date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        
        if seconds < 5 { return "just now" }
        if seconds < 60 { return "\(seconds)s ago" }
        
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m ago" }
        
        return date.formatted(date: .omitted, time: .shortened)
    }
    
    func exportBossDailyReport() -> URL {
        var csv = "Driver,Truck,Loads,Pickup Tons,Delivery Tons,Open Loads,Delivered Loads,Difference\n"
        
        let grouped = Dictionary(grouping: allLoads) { $0.driverName }
        
        for (driverName, driverLoads) in grouped.sorted(by: { $0.key < $1.key }) {
            let truck = driverLoads.first?.truck ?? "Unknown"
            let loads = driverLoads.count
            
            let pickupTons = driverLoads.reduce(0.0) { $0 + $1.pickupTons }
            let deliveryTons = driverLoads.reduce(0.0) { $0 + $1.deliveryTons }
            
            let delivered = driverLoads.filter {
                !$0.deliveryTicketNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }.count
            
            let open = loads - delivered
            let difference = pickupTons - deliveryTons
            
            csv += "\(driverName),\(truck),\(loads),\(pickupTons),\(deliveryTons),\(open),\(delivered),\(difference)\n"
        }
        
        csv += "\n"
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
                $0.deliveryTicketNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }.count
        case .delivered:
            return allLoads.filter {
                !$0.deliveryTicketNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }.count
        case .open:
            return allLoads.filter {
                $0.deliveryTicketNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
        allLoads = []
        selectedDriver = nil
        
        print("Logged out")
    }
    // 🔥 IMPORT
    func importCSVs(urls: [URL]) async {
        var summaryDict: [String: DriverSummary] = [:]
        var tempLoads: [ReportLoadItem] = []
        
        for url in urls {
            do {
                let text = try String(contentsOf: url, encoding: .utf8)
                let rows = text.components(separatedBy: "\n").dropFirst()
                
                for row in rows where !row.trimmingCharacters(in: .whitespaces).isEmpty {
                    let columns = row.components(separatedBy: ",")
                    if columns.count < 10 { continue }
                    
                    let driverName = columns[2].trimmed()
                    let truck = columns[3].trimmed()
                    
                    let pickupCompany = columns[4].trimmed()
                    let pickupTicket = columns[5].trimmed()
                    let pickupTons = Double(columns[6].trimmed()) ?? 0
                    
                    let deliveryCompany = columns[7].trimmed()
                    let deliveryTicket = columns[8].trimmed()
                    let deliveryTons = Double(columns[9].trimmed()) ?? 0
                    
                    if summaryDict[driverName] == nil {
                        summaryDict[driverName] = DriverSummary(
                            name: driverName,
                            truck: truck,
                            loads: 0,
                            tons: 0,
                            fuel: 0,
                            status: "unknown"
                        )
                    }
                    
                    summaryDict[driverName]?.loads += 1
                    summaryDict[driverName]?.tons += pickupTons
                    
                    tempLoads.append(
                        ReportLoadItem(
                            driverName: driverName,
                            truck: truck,
                            pickupCompany: pickupCompany,
                            pickupTicketNumber: pickupTicket,
                            pickupTons: pickupTons,
                            deliveryCompany: deliveryCompany,
                            deliveryTicketNumber: deliveryTicket,
                            deliveryTons: deliveryTons
                        )
                    )
                }
            } catch {
                print(error)
            }
        }
        
        allLoads = tempLoads
    }
    
    // 🔥 EXPORT
    func exportCombinedCSV() -> URL {
        var csv = "Driver,Truck,Loads,Tons\n"
        
        for d in combinedReports {
            csv += "\(d.name),\(d.truck),\(d.loads),\(d.tons)\n"
        }
        
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Report.csv")
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
                var tempLoads: [ReportLoadItem] = []
                
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
                        if columns.count < 10 { continue }
                        
                        let driverName = columns[2].trimmed()
                        let truck = columns[3].trimmed()
                        
                        let pickupCompany = columns[4].trimmed()
                        let pickupTicket = columns[5].trimmed()
                        let pickupTons = Double(columns[6].trimmed()) ?? 0
                        
                        let deliveryCompany = columns[7].trimmed()
                        let deliveryTicket = columns[8].trimmed()
                        let deliveryTons = Double(columns[9].trimmed()) ?? 0
                        
                        if summaryDict[driverName] == nil {
                            summaryDict[driverName] = DriverSummary(
                                name: driverName,
                                truck: truck,
                                loads: 0,
                                tons: 0,
                                fuel: 0,
                                status: "unknown"
                            )
                        }
                        
                        summaryDict[driverName]?.loads += 1
                        summaryDict[driverName]?.tons += pickupTons
                        
                        tempLoads.append(
                            ReportLoadItem(
                                driverName: driverName,
                                truck: truck,
                                pickupCompany: pickupCompany,
                                pickupTicketNumber: pickupTicket,
                                pickupTons: pickupTons,
                                deliveryCompany: deliveryCompany,
                                deliveryTicketNumber: deliveryTicket,
                                deliveryTons: deliveryTons
                            )
                        )
                    }
                }
                
                // 🔥 Move CSV write OFF main thread too
                DispatchQueue.global(qos: .background).async {
                    generateAdminActiveCSV(from: tempLoads)
                }
                
                // ✅ UI update safely
                await MainActor.run {
                    
                    let deliveredCount = tempLoads.filter {
                        !$0.deliveryTicketNumber.isEmpty
                    }.count
                    
                    if deliveredCount > lastDeliveredCount {
                        let newDeliveries = deliveredCount - lastDeliveredCount
                        
                        sendAdminNotification(
                            message: "\(newDeliveries) new delivery(s)"
                        )
                    }
                    
                    lastDeliveredCount = deliveredCount
                    
                    withAnimation {
                        allLoads = tempLoads
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

    
    func generateAdminActiveCSV(from loads: [ReportLoadItem]) {

        var csv = "Last Updated,\(Date())\n\n"

        // 🔥 BUILD SUMMARY FROM LOADS (no external dependency)
        var summaryDict: [String: DriverSummary] = [:]

        for load in loads {

            if summaryDict[load.driverName] == nil {
                summaryDict[load.driverName] = DriverSummary(
                    name: load.driverName,
                    truck: load.truck,
                    loads: 0,
                    tons: 0,
                    fuel: 0,
                    status: "active"
                )
            }

            summaryDict[load.driverName]?.loads += 1
            summaryDict[load.driverName]?.tons += load.pickupTons
        }

        let summaries = Array(summaryDict.values)

        // 🔥 SUMMARY SECTION
        csv += "Driver,Truck,Loads,Tons,Fuel,Status\n"

        for d in summaries {
            csv += "\(d.name),\(d.truck),\(d.loads),\(d.tons),\(d.fuel),\(d.status)\n"
        }

        csv += "\n\n"

        // 🔥 DETAILED LOADS SECTION
        csv += "Date,Time,Driver,Truck,PickupCompany,PickupTicket,PickupTons,DeliveryCompany,DeliveryTicket,DeliveryTons\n"

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"

        for load in loads {
            let date = dateFormatter.string(from: Date()) // upgrade later if you store date
            let time = timeFormatter.string(from: Date())

            csv += "\(date),\(time),\(load.driverName),\(load.truck),\(load.pickupCompany),\(load.pickupTicketNumber),\(load.pickupTons),\(load.deliveryCompany),\(load.deliveryTicketNumber),\(load.deliveryTons)\n"
        }

        let fileName = "ADMIN-ACTIVE.csv"

        // ✅ ALWAYS WRITE LOCAL (FAST — NO FREEZE)
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

        // ☁️ OPTIONAL: Sync to iCloud (non-blocking)
        
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
}
