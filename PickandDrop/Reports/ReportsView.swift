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
                                
                                if let settings {
                                    
                                    let loads =
                                    await LoadSupabaseManager.shared.fetchLoads()
                                    
                                    weeklyInvoiceURL =
                                    WeeklyInvoiceGenerator.createWeeklyInvoicePDF(
                                        settings: settings,
                                        weekDate: selectedInvoiceWeek,
                                        loads: loads
                                        // archived defaults to false
                                    )
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
                                
                                if let settings {
                                    
                                    let loads =
                                    await LoadSupabaseManager.shared.fetchLoads()
                                    
                                    weeklyInvoiceURL =
                                    WeeklyInvoiceGenerator.createWeeklyInvoicePDF(
                                        settings: settings,
                                        weekDate: selectedInvoiceWeek,
                                        loads: loads,
                                        archived: true
                                    )
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

            Text(
                "\(settings?.pickup_company_name ?? "Pickup") → \(settings?.dropoff_company_name ?? "Dropoff")"
            )
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
    
    func closeWeek() async {
        
        guard let settings else { return }
        
        let loads = await LoadSupabaseManager.shared.fetchLoads()
        let fuel = await FuelSupabaseManager.shared.fetchFuel()
        
        let completedLoads = loads.filter {
            $0.status == "delivered" &&
            $0.is_archived != true
        }
        
        print("📦 New loads archived:", completedLoads.count)
        
        CloseWeekArchiveExporter.appendLoads(
            loads: completedLoads,
            settings: settings
        )
        
        CloseWeekArchiveExporter.appendFuel(
            fuel: fuel
        )
        
        await FuelReceiptManager.shared.saveAllReceiptsToPhotos(
            fuelEntries: fuel
        )
        
        await FuelSupabaseManager.shared.deleteAllFuel()
        
        //await LoadSupabaseManager.shared.deleteArchivedLoads()
        
        await LoadSupabaseManager.shared.archiveDeliveredLoads()
        
        print("✅ Week closed")
    }
}

//CloseWeekArchiveExplorer
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
}


