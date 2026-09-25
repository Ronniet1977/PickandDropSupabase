//
//  ReportsView.swift
//  PickandDrop
//
//  Created by Ronald Thayer Jr on 5/7/26.
//

import SwiftUI
import SwiftData
import QuickLook

struct ReportsView: View {

    @State private var settings: SupabaseCompanySettings?
    @State private var weeklyInvoiceURL: URL?
    @State private var selectedInvoiceWeek = Date()
    @State private var showCloseWeekAlert = false
    @State private var showInvoiceRates = false
    @State private var showInvoiceDropoffPicker = false
    @State private var invoiceIsArchived = false
    @State private var invoiceDropoffs: [String] = []
    
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
                    VStack(spacing: 22) {

                        headerCard

                        DatePicker(
                            "Invoice Week",
                            selection: $selectedInvoiceWeek,
                            displayedComponents: .date
                        )
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .foregroundStyle(.white)
                        
                        Button {
                            Task {
                                let loads =
                                    await LoadSupabaseManager.shared.fetchLoads()

                                let dropoffs =
                                    availableInvoiceDropoffs(
                                        from: loads,
                                        archived: false
                                    )

                                await MainActor.run {
                                    invoiceDropoffs = dropoffs
                                    invoiceIsArchived = false
                                    showInvoiceDropoffPicker = true
                                }
                            }
                        } label: {
                            reportCard(
                                title: "Weekly Invoice",
                                subtitle: "Generate weekly invoice PDF",
                                icon: "doc.richtext.fill",
                                color: .blue
                            )
                        }
                        
                        Button {
                            Task {
                                let loads =
                                    await LoadSupabaseManager.shared.fetchLoads()

                                let dropoffs =
                                    availableInvoiceDropoffs(
                                        from: loads,
                                        archived: true
                                    )

                                await MainActor.run {
                                    invoiceDropoffs = dropoffs
                                    invoiceIsArchived = true
                                    showInvoiceDropoffPicker = true
                                }
                            }
                        } label: {
                            reportCard(
                                title: "Archived Weekly Invoice",
                                subtitle: "Generate invoice from archived loads",
                                icon: "archivebox.fill",
                                color: .purple
                            )
                        }
                        
                        Button {
                            showInvoiceRates = true
                        } label: {
                            reportCard(
                                title: "Invoice Rates",
                                subtitle: "Update rate & fuel surcharge",
                                icon: "dollarsign.circle.fill",
                                color: .green
                            )
                        }
                        
                        Button(role: .destructive) {
                            showCloseWeekAlert = true
                        } label: {
                            reportCard(
                                title: "Close Week",
                                subtitle: "Archive & reset week",
                                icon: "archivebox.fill",
                                color: .red
                            )
                        }
                        
                        NavigationLink {
                            DailyTimeTicketView()
                        } label: {
                            reportCard(
                                title: "Daily Time Ticket",
                                subtitle: "Start, end, and total hours by day",
                                icon: "clock.badge.checkmark.fill",
                                color: .blue
                            )
                        }
                        
                        NavigationLink {
                            WeeklyDriverVerificationView()
                        } label: {
                            reportCard(
                                title: "Weekly Driver Verification",
                                subtitle: "Verify loads and billing totals by date range",
                                icon: "checklist.checked",
                                color: .blue
                            )
                        }

                        NavigationLink {
                            DailyDriverSummaryView()
                        } label: {
                            reportCard(
                                title: "Daily Driver Summary",
                                subtitle: "Driver loads and tons by day",
                                icon: "person.3.fill",
                                color: .green
                            )
                        }

                        NavigationLink {
                            CompletedLoadsReportView()
                        } label: {
                            reportCard(
                                title: "Completed Loads",
                                subtitle: "Delivered Supabase loads",
                                icon: "checkmark.circle.fill",
                                color: .orange
                            )
                        }

                        NavigationLink {
                            FuelReportsView()
                        } label: {
                            reportCard(
                                title: "Fuel Reports",
                                subtitle: "Fuel totals from Supabase",
                                icon: "fuelpump.fill",
                                color: .red
                            )
                        }
                    }
                    .padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .alert("Close Week?", isPresented: $showCloseWeekAlert) {
                Button("Cancel", role: .cancel) { }
                
                Button("Close Week", role: .destructive) {
                    Task {
                        await closeWeek()
                    }
                }
            } message: {
                Text("This will archive completed loads and fuel to local CSV files, save receipts to Photos, clear weekly fuel, and reset the dashboard.")
            }
            .alert(
                invoiceIsArchived
                    ? "Archived Invoice"
                    : "Weekly Invoice",
                isPresented: $showInvoiceDropoffPicker
            ) {

                ForEach(invoiceDropoffs, id: \.self) { dropoff in

                    Button(dropoff) {
                        Task {
                            await generateInvoice(
                                dropoff: dropoff,
                                archived: invoiceIsArchived
                            )
                        }
                    }
                }

                Button("Cancel", role: .cancel) { }

            } message: {

                if invoiceDropoffs.isEmpty {
                    Text("No dropoffs found for this week.")
                } else {
                    Text("Choose a dropoff.")
                }
            }
            .onAppear {
                Task {
                    let loadedSettings =
                        await CompanySupabaseManager.shared.fetchCompanySettings()

                    await MainActor.run {
                        settings = loadedSettings
                    }
                }
            }
            .sheet(isPresented: $showInvoiceRates) {
                if let settings {
                    NavigationStack {
                        EditCompanyInfoView(
                            settings: settings,
                            onSaved: {
                                Task {
                                    let loadedSettings =
                                    await CompanySupabaseManager.shared.fetchCompanySettings()
                                    
                                    await MainActor.run {
                                        self.settings = loadedSettings
                                    }
                                }
                            }
                        )
                    }
                }
            }
            .quickLookPreview($weeklyInvoiceURL)
        }
    }

    var headerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Reports")
                .font(.system(size: 38, weight: .bold))
                .foregroundStyle(.white)

            Text(settings?.trucking_company_name ?? "Trucking Company")
                .font(.headline)
                .foregroundStyle(.blue)

            Text("All Routes")
            .font(.caption)
            .foregroundStyle(.white.opacity(0.7))

            Text("Supabase Reports")
                .foregroundStyle(.white.opacity(0.7))

            Divider()

            HStack {
                reportStat(title: "Source", value: "Live")
                Spacer()
                reportStat(title: "Files", value: "0")
                Spacer()
                reportStat(title: "CSV Legacy", value: "Off")
            }
        }
        .padding(24)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 30))
    }

    func reportCard(
        title: String,
        subtitle: String,
        icon: String,
        color: Color
    ) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 44, height: 44)
                .background(color.opacity(0.18))
                .clipShape(RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.white.opacity(0.4))
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    func reportStat(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))

            Text(value)
                .font(.title3.bold())
                .foregroundStyle(.white)
        }
    }
    
    func availableInvoiceDropoffs(
        from loads: [SupabaseLoad],
        archived: Bool
    ) -> [String] {

        var calendar = Calendar.current
        calendar.firstWeekday = 2   // Monday

        guard let weekInterval =
            calendar.dateInterval(
                of: .weekOfYear,
                for: selectedInvoiceWeek
            )
        else {
            return []
        }

        let names =
            loads.compactMap { load -> String? in

                guard load.is_archived == archived else {
                    return nil
                }

                guard
                    (load.status ?? "")
                        .lowercased() == "delivered"
                else {
                    return nil
                }

                let dateText =
                    load.delivered_at
                    ?? load.picked_up_at
                    ?? load.created_at
                    ?? ""

                let formatter =
                    ISO8601DateFormatter()

                formatter.formatOptions = [
                    .withInternetDateTime,
                    .withFractionalSeconds
                ]

                let date =
                    formatter.date(from: dateText)
                    ?? ISO8601DateFormatter()
                        .date(from: dateText)

                guard
                    let date,
                    weekInterval.contains(date)
                else {
                    return nil
                }

                let dropoff =
                    load.dropoff_location?
                        .trimmingCharacters(
                            in: .whitespacesAndNewlines
                        ) ?? ""

                return dropoff.isEmpty
                    ? nil
                    : dropoff
            }

        return Array(Set(names))
            .sorted {
                $0.localizedCaseInsensitiveCompare($1)
                    == .orderedAscending
            }
    }
    
    func generateInvoice(
        dropoff: String,
        archived: Bool
    ) async {
        
        guard let settings else {
            return
        }
        
        async let loadedLoads =
        LoadSupabaseManager.shared.fetchLoads()
        
        async let loadedShifts =
        ShiftSupabaseManager.shared.fetchShifts()
        
        let loads = await loadedLoads
        let shifts = await loadedShifts
        
        let url =
        WeeklyInvoiceGenerator.createWeeklyInvoicePDF(
            settings: settings,
            weekDate: selectedInvoiceWeek,
            loads: loads,
            shifts: shifts,
            dropoffLocation: dropoff,
            archived: archived
        )
        
        await MainActor.run {
            weeklyInvoiceURL = url
        }
    }
    
    func closeWeek() async {

        let loads =
            await LoadSupabaseManager.shared.fetchLoads()

        let fuel =
            await FuelSupabaseManager.shared.fetchFuel()

        let completedLoads =
            loads.filter {
                $0.status == "delivered" &&
                $0.is_archived != true
            }

        print(
            "📦 Loads being archived:",
            completedLoads.count
        )

        print(
            "⛽ Fuel entries being archived:",
            fuel.count
        )

        // Save receipt photos to the phone.
        // FuelReceiptManager also removes the receipt
        // image from Supabase Storage after it saves.
        await FuelReceiptManager.shared
            .saveAllReceiptsToPhotos(
                fuelEntries: fuel
            )

        // Keep fuel records for Fuel Reports,
        // but remove them from the active weekly view.
        await FuelSupabaseManager.shared
            .archiveAllFuel()

        // Keep delivered loads in Supabase history,
        // but remove them from the active week.
        await LoadSupabaseManager.shared
            .archiveDeliveredLoads()

        print("✅ Week closed")
    }
}

/*//CloseWeekArchiveExplorer
import Foundation

struct CloseWeekArchiveExporter {
    
    static func archiveFolder() -> URL {
        let folder = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PickandDrop")
            .appendingPathComponent("Archives")
        
        try? FileManager.default.createDirectory(
            at: folder,
            withIntermediateDirectories: true
        )
        
        return folder
    }
    
    static func appendLoads(
        loads: [SupabaseLoad],
        settings: SupabaseCompanySettings?
    ) {
        let url = archiveFolder()
            .appendingPathComponent("Load_Archive.csv")
        
        let completedLoads = loads.filter {
            $0.status == "delivered" &&
            $0.is_archived != true
        }
        
        let needsHeader =
        !FileManager.default.fileExists(atPath: url.path)
        
        var csv = ""
        
        if needsHeader {
            csv += "Archived At,Driver,Truck,Pickup Ticket,Pickup Tons,Delivery Ticket,Delivery Tons,Status,Picked Up At,Delivered At\n"
        }
        
        for load in completedLoads {
            
            csv += [
                csvSafe(Date().formatted()),
                csvSafe(load.driver_name ?? ""),
                csvSafe(load.truck_number ?? ""),
                csvSafe(load.pickup_ticket_number ?? ""),
                String(format: "%.2f", load.pickup_tons ?? 0),
                csvSafe(load.delivery_ticket_number ?? ""),
                String(format: "%.2f", load.delivery_tons ?? 0),
                csvSafe(load.status ?? ""),
                csvSafe(load.picked_up_at ?? ""),
                csvSafe(load.delivered_at ?? "")
            ].joined(separator: ",") + "\n"
        }
        
        append(csv, to: url)
    }
    
    static func appendFuel(
        fuel: [SupabaseFuel]
    ) {
        let url = archiveFolder()
            .appendingPathComponent("Fuel_Archive.csv")
        
        let needsHeader =
        !FileManager.default.fileExists(atPath: url.path)
        
        var csv = ""
        
        if needsHeader {
            csv += "Archived At,Driver,Truck,Amount,Created At,Receipt Saved\n"
        }
        
        for entry in fuel {
            csv += [
                csvSafe(Date().formatted()),
                csvSafe(entry.driver_name ?? ""),
                csvSafe(entry.truck_number ?? ""),
                String(format: "%.2f", entry.amount ?? 0),
                csvSafe(entry.created_at ?? ""),
                entry.receipt_path == nil ? "true" : "false"
            ].joined(separator: ",") + "\n"
        }
        
        append(csv, to: url)
    }
    
    static func append(_ text: String, to url: URL) {
        if let handle = try? FileHandle(forWritingTo: url) {
            _ = try? handle.seekToEnd()
            if let data = text.data(using: .utf8) {
                try? handle.write(contentsOf: data)
            }
            try? handle.close()
        } else {
            try? text.write(
                to: url,
                atomically: true,
                encoding: .utf8
            )
        }
        
        print("✅ Archived CSV:", url.lastPathComponent)
    }
    
    static func csvSafe(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}*/


