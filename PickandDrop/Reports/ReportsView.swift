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
    
    @Query var companySettings: [CompanySettings]
    @State private var reportFiles: [URL] = []
    @State private var invoiceURL: URL?
    
    
    var settings: CompanySettings? {
        companySettings.first
    }

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

                        // HEADER

                        VStack(alignment: .leading, spacing: 14) {

                            Text("Reports")
                                .font(.system(size: 38, weight: .bold))
                                .foregroundStyle(.white)
                            
                            Text(
                                settings?.truckingCompanyName
                                ?? "Trucking Company"
                            )
                            .font(.headline)
                            .foregroundStyle(.blue)
                            
                            Text(
                                "\(settings?.pickupCompanyName ?? "Pickup") → \(settings?.dropoffCompanyName ?? "Dropoff")"
                            )
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))

                            Text("Invoices & Shift Reports")
                                .foregroundStyle(.white.opacity(0.7))

                            Divider()

                            HStack {

                                reportStat(
                                    title: "Reports",
                                    value: "\(reportFiles.count)"
                                )

                                Spacer()

                                reportStat(
                                    title: "Final",
                                    value: "\(reportFiles.filter { $0.lastPathComponent.contains("FINAL") }.count)"
                                )

                                Spacer()

                                reportStat(
                                    title: "Active",
                                    value: "\(reportFiles.filter { !$0.lastPathComponent.contains("FINAL") }.count)"
                                )
                            }
                        }
                        .padding(24)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 30))

                        // EMPTY STATE

                        if reportFiles.isEmpty {

                            VStack(spacing: 16) {

                                Image(systemName: "doc.text.magnifyingglass")
                                    .font(.system(size: 58))
                                    .foregroundStyle(.gray)

                                Text("No Reports Yet")
                                    .font(.title2.bold())
                                    .foregroundStyle(.white)

                                Text("Generated reports will appear here.")
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                            .padding(.top, 80)
                        }

                        // REPORT CARDS

                        ForEach(reportFiles, id: \.self) { file in
                            
                            VStack(alignment: .leading, spacing: 18) {
                                
                                NavigationLink {
                                    
                                    CSVPreviewView(
                                        fileURL: file,
                                        generatePickupInvoice: generatePickupInvoice,
                                        generateDeliveryInvoice: generateDeliveryInvoice
                                    )
                                    
                                } label: {
                                    
                                    VStack(alignment: .leading, spacing: 12) {
                                        
                                        HStack {
                                            
                                            VStack(alignment: .leading, spacing: 6) {
                                                
                                                Text(file.lastPathComponent)
                                                    .font(.headline)
                                                    .foregroundStyle(.white)
                                                    .multilineTextAlignment(.leading)
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                                
                                                Text(
                                                    file.lastPathComponent.contains("FINAL")
                                                    ? "Completed Shift Report"
                                                    : "Active Shift Report"
                                                )
                                                .font(.caption)
                                                .foregroundStyle(.white.opacity(0.7))
                                            }
                                            
                                            Spacer()
                                            
                                            Image(systemName: "chevron.right")
                                                .foregroundStyle(.white.opacity(0.4))
                                        }
                                        
                                        HStack(spacing: 12) {
                                            
                                            Label(
                                                file.lastPathComponent.contains("FINAL")
                                                ? "Final"
                                                : "Active",
                                                systemImage:
                                                    file.lastPathComponent.contains("FINAL")
                                                ? "checkmark.circle.fill"
                                                : "clock.fill"
                                            )
                                            .font(.caption.bold())
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(
                                                file.lastPathComponent.contains("FINAL")
                                                ? .green.opacity(0.2)
                                                : .blue.opacity(0.2)
                                            )
                                            .foregroundStyle(
                                                file.lastPathComponent.contains("FINAL")
                                                ? .green
                                                : .blue
                                            )
                                            .clipShape(Capsule())
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .onAppear {
                loadFiles()
            }
            .quickLookPreview($invoiceURL)
        }
    }
    
    func reportStat(
        title: String,
        value: String
    ) -> some View {

        VStack(alignment: .leading, spacing: 4) {

            Text(title)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))

            Text(value)
                .font(.title.bold())
                .foregroundStyle(.white)
        }
    }
    
    func generateInvoice(from file: URL) {

        do {

            let text = try String(contentsOf: file, encoding: .utf8)

            let rows = text.components(separatedBy: .newlines)
            
            print(rows.first ?? "NO HEADER")

            if rows.count > 1 {
                print(rows[1])
            }
            
            var csvLoads: [CSVLoad] = []

            for row in rows.dropFirst() {

                if row.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    continue
                }

                let cleaned = row.replacingOccurrences(of: "\"", with: "")

                let columns = cleaned.components(separatedBy: ",")

                print("COLUMN COUNT:", columns.count)
                print(columns)

                if columns.count < 11 {
                    continue
                }

                let load = CSVLoad(
                    date: columns[0],
                    time: columns[1],
                    driverName: columns[2],
                    truck: columns[3],
                    pickupTicket: columns[4],
                    pickupTons: Double(columns[5]) ?? 0,
                    deliveryTicket: columns[6],
                    deliveryTons: Double(columns[7]) ?? 0,
                    pickedUp: columns[8],
                    delivered: columns[9]
                )

                csvLoads.append(load)
            }
            
            print("CSV LOAD COUNT:", csvLoads.count)
            
            let deliveredLoads = csvLoads.filter {
                $0.isDelivered
            }

            invoiceURL = InvoiceGenerator.createInvoicePDF(
                companyName: settings?.truckingCompanyName ?? "Trucking Company",
                pickupCompany: settings?.pickupCompanyName ?? "Pickup",
                dropoffCompany: settings?.dropoffCompanyName ?? "Dropoff",
                invoiceTitle: "Invoice",
                driverName: deliveredLoads.first?.driverName ?? "Unknown",
                truckNumber: deliveredLoads.first?.truck ?? "Unknown",
                loads: deliveredLoads,
                ratePerTon: settings?.ratePerTon ?? 0,
                useDeliveryTons: true
            )

            print(invoiceURL?.path ?? "NO PDF URL")

        } catch {

            print("Invoice parse error:", error)
        }
    }
    
    func generatePickupInvoice(from file: URL) {

        do {

            let text = try String(contentsOf: file, encoding: .utf8)

            let rows = text.components(separatedBy: .newlines)

            var csvLoads: [CSVLoad] = []

            for row in rows.dropFirst() {

                if row.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    continue
                }

                let cleaned = row.replacingOccurrences(of: "\"", with: "")

                let columns = cleaned.components(separatedBy: ",")

                if columns.count < 11 {
                    continue
                }

                let load = CSVLoad(
                    date: columns[0],
                    time: columns[1],
                    driverName: columns[2],
                    truck: columns[3],
                    pickupTicket: columns[4],
                    pickupTons: Double(columns[5]) ?? 0,
                    deliveryTicket: columns[6],
                    deliveryTons: Double(columns[7]) ?? 0,
                    pickedUp: columns[8],
                    delivered: columns[9]
                )

                csvLoads.append(load)
            }

            // ✅ PICKUP FILTER
            let pickupLoads = csvLoads.filter {
                !$0.pickupTicket.isEmpty
            }

            invoiceURL = InvoiceGenerator.createInvoicePDF(
                companyName: settings?.truckingCompanyName ?? "Trucking Company",
                pickupCompany: settings?.pickupCompanyName ?? "Pickup",
                dropoffCompany: settings?.dropoffCompanyName ?? "Dropoff",
                invoiceTitle: "\(settings?.pickupCompanyName ?? "Pickup") Invoice",
                driverName: pickupLoads.first?.driverName ?? "Unknown",
                truckNumber: pickupLoads.first?.truck ?? "Unknown",
                loads: pickupLoads,
                ratePerTon: settings?.ratePerTon ?? 0,
                useDeliveryTons: false
            )

            print(invoiceURL?.path ?? "NO PDF URL")

        } catch {

            print("Pickup invoice parse error:", error)
        }
    }
    
    func generateDeliveryInvoice(from file: URL) {

        do {

            let text = try String(contentsOf: file, encoding: .utf8)

            let rows = text.components(separatedBy: .newlines)

            var csvLoads: [CSVLoad] = []

            for row in rows.dropFirst() {

                if row.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    continue
                }

                let cleaned = row.replacingOccurrences(of: "\"", with: "")

                let columns = cleaned.components(separatedBy: ",")

                if columns.count < 11 {
                    continue
                }

                let load = CSVLoad(
                    date: columns[0],
                    time: columns[1],
                    driverName: columns[2],
                    truck: columns[3],
                    pickupTicket: columns[4],
                    pickupTons: Double(columns[5]) ?? 0,
                    deliveryTicket: columns[6],
                    deliveryTons: Double(columns[7]) ?? 0,
                    pickedUp: columns[8],
                    delivered: columns[9]
                )

                csvLoads.append(load)
            }

            // ✅ DELIVERY FILTER
            let deliveryLoads = csvLoads.filter {
                $0.isDelivered
            }

            invoiceURL = InvoiceGenerator.createInvoicePDF(
                companyName: settings?.truckingCompanyName ?? "Trucking Company",
                pickupCompany: settings?.pickupCompanyName ?? "Pickup",
                dropoffCompany: settings?.dropoffCompanyName ?? "Dropoff",
                invoiceTitle: "\(settings?.dropoffCompanyName ?? "Dropoff") Invoice",
                driverName: deliveryLoads.first?.driverName ?? "Unknown",
                truckNumber: deliveryLoads.first?.truck ?? "Unknown",
                loads: deliveryLoads,
                ratePerTon: settings?.ratePerTon ?? 0,
                useDeliveryTons: true
            )

            print(invoiceURL?.path ?? "NO PDF URL")

        } catch {

            print("Delivery invoice parse error:", error)
        }
    }
            

    func loadFiles() {

        let folder = StorageManager.truckReportsFolder()

        do {

            let files = try FileManager.default.contentsOfDirectory(
                at: folder,
                includingPropertiesForKeys: nil
            )

            reportFiles = files
                .filter {
                    $0.pathExtension == "csv"
                }
                .sorted {
                    $0.lastPathComponent > $1.lastPathComponent
                }

        } catch {

            print("❌ Failed loading reports:", error)
        }
    }
}
