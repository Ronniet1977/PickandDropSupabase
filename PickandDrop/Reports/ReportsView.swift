//
//  ReportsView.swift
//  PickandDrop
//
//  Created by Ronald Thayer Jr on 5/7/26.
//

import SwiftUI
import QuickLook

struct ReportsView: View {

    var allLoads: [LoadItem]

    @State private var reportFiles: [URL] = []
    @State private var invoiceURL: URL?

    var body: some View {
        
        NavigationStack {
            
            List {
                ForEach(reportFiles, id: \.self) { file in
                    
                    VStack(alignment: .leading, spacing: 8) {

                        NavigationLink {

                            CSVPreviewView(
                                fileURL: file,
                                generatePickupInvoice: generatePickupInvoice,
                                generateDeliveryInvoice: generateDeliveryInvoice
                            )

                        } label: {

                            VStack(alignment: .leading, spacing: 4) {

                                Text(file.lastPathComponent)
                                    .font(.headline)

                                if file.lastPathComponent.contains("FINAL") {

                                    Text("✅ Final Report")
                                        .font(.caption)
                                        .foregroundStyle(.green)

                                } else {

                                    Text("🟢 Active Report")
                                        .font(.caption)
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Reports")
            .onAppear {
                loadFiles()
            }
            .quickLookPreview($invoiceURL)
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
                driverName: deliveredLoads.first?.driverName ?? "Unknown",
                truckNumber: deliveredLoads.first?.truck ?? "Unknown",
                loads: deliveredLoads,
                ratePerTon: 7.50
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
                companyName: "BRC",
                invoiceTitle: "Pickup Invoice",
                driverName: pickupLoads.first?.driverName ?? "Unknown",
                truckNumber: pickupLoads.first?.truck ?? "Unknown",
                loads: pickupLoads,
                ratePerTon: 7.50
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
                companyName: "HoneyGo",
                invoiceTitle: "Delivery Invoice",
                driverName: deliveryLoads.first?.driverName ?? "Unknown",
                truckNumber: deliveryLoads.first?.truck ?? "Unknown",
                loads: deliveryLoads,
                ratePerTon: 7.50
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
