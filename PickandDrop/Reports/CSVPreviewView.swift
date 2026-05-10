//
//  CSVPreviewView.swift
//  PickandDrop
//
//  Created by Ronald Thayer Jr on 5/7/26.
//

import SwiftUI
import SwiftData

struct CSVPreviewView: View {

    let fileURL: URL
    let generatePickupInvoice: (URL) -> Void
    let generateDeliveryInvoice: (URL) -> Void
    
    @Query var companySettings: [CompanySettings]
    @State private var loads: [CSVLoad] = []
    @State private var selectedLoad: CSVLoad?
    @State private var editedPickupTicket = ""
    @State private var editedPickupTons = ""
    @State private var editedDeliveryTons = ""
    
    var settings: CompanySettings? {
        companySettings.first
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

                VStack(spacing: 16) {
                    
                    summaryCard
                    
                    ForEach(loads, id: \.id) { load in
                        
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Ticket \(load.pickupTicket)")
                                        .font(.headline)
                                    
                                    HStack(spacing: 12) {

                                        Text(
                                            "\(settings?.pickupCompanyName ?? "Pickup"): \(load.pickupTons, specifier: "%.0f") Tons"
                                        )
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.blue)

                                        Text(
                                            "\(settings?.dropoffCompanyName ?? "Dropoff"): \(load.deliveryTons, specifier: "%.0f") Tons"
                                        )
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.orange)
                                    }
                                    .font(.subheadline)
                                }
                                
                                Spacer()
                                
                                if load.isDelivered {
                                    
                                    Text("✅ Delivered")
                                        .fontWeight(.bold)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(.green.opacity(0.15))
                                        .foregroundStyle(.green)
                                        .clipShape(Capsule())
                                    
                                } else {
                                    
                                    Text("🟠 Picked Up")
                                        .fontWeight(.bold)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(.orange.opacity(0.15))
                                        .foregroundStyle(.orange)
                                        .clipShape(Capsule())
                                }
                            }
                            
                            Divider()
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Driver: \(load.driverName)")
                                    .fontWeight(.medium)
                                
                                Text("Truck: \(load.truck)")
                                    .foregroundStyle(.secondary)
                                Text(
                                    "\(settings?.pickupCompanyName ?? "Pickup") → \(settings?.dropoffCompanyName ?? "Dropoff")"
                                )
                                    .font(.caption.bold())
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(.blue.opacity(0.15))
                                    .foregroundStyle(.blue)
                                    .clipShape(Capsule())
                                
                                Divider()
                                
                                Text(
                                    "\(settings?.pickupCompanyName ?? "Pickup") Ticket: \(load.pickupTicket)"
                                )
                                .foregroundStyle(.secondary)

                                if load.isDelivered {
                                    
                                    Text(
                                        "\(settings?.dropoffCompanyName ?? "Dropoff") Ticket: \(load.deliveryTicket)"
                                    )
                                    .foregroundStyle(.secondary)
                                    
                                    let duration = durationText(
                                        pickup: load.pickedUp,
                                        delivered: load.delivered
                                    )
                                    
                                    let pickupText = formattedTimestamp(load.pickedUp)
                                    let deliveredText = formattedTimestamp(load.delivered)
                                    
                                    Text("Picked Up: \(pickupText)")
                                        .foregroundStyle(.secondary)
                                    
                                    Text("Delivered: \(deliveredText)")
                                        .foregroundStyle(.secondary)
                                    
                                    Text("Duration: \(duration)")
                                        .foregroundStyle(.blue)
                                        .fontWeight(.semibold)
                                    
                                    HStack {
                                        
                                        Button(
                                            "\(settings?.pickupCompanyName ?? "Pickup") Invoice"
                                        ) {
                                            generatePickupInvoice(fileURL)
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .tint(.blue)
                                        
                                        Button(
                                            "\(settings?.dropoffCompanyName ?? "Dropoff") Invoice"
                                        ) {
                                            generateDeliveryInvoice(fileURL)
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .tint(.green)
                                    }
                                    .padding(.top, 6)
                                    
                                } else {
                                    
                                    Text("Not delivered yet")
                                        .foregroundStyle(.orange)
                                }
                            }
                            .font(.subheadline)
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .onTapGesture {
                            selectedLoad = load
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle(fileURL.lastPathComponent)
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

                    VStack(spacing: 24) {
                        Text("Edit Load")
                            .font(.largeTitle.bold())
                            .foregroundStyle(.white)

                        VStack(spacing: 18) {

                            TextField(
                                "\(settings?.pickupCompanyName ?? "Pickup") Ticket",
                                text: $editedPickupTicket
                            )

                            TextField(
                                "\(settings?.pickupCompanyName ?? "Pickup") Tons",
                                text: $editedPickupTons
                            )

                            TextField(
                                "\(settings?.dropoffCompanyName ?? "Dropoff") Tons",
                                text: $editedDeliveryTons
                            )
                        }
                        .textFieldStyle(.roundedBorder)
                        .padding()

                        Button("Save Changes") {

                            if let index = loads.firstIndex(where: {
                                $0.id == load.id
                            }) {

                                loads[index].pickupTicket = editedPickupTicket

                                loads[index].pickupTons =
                                    Double(editedPickupTons) ?? 0

                                loads[index].deliveryTons =
                                    Double(editedDeliveryTons) ?? 0
                            }

                            selectedLoad = nil
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)

                        Spacer()
                    }
                    .padding()
                }
                .onAppear {

                    editedPickupTicket = load.pickupTicket

                    editedPickupTons =
                        String(format: "%.2f", load.pickupTons)

                    editedDeliveryTons =
                        String(format: "%.2f", load.deliveryTons)
                }
            }
        }
        .onAppear {
            parseCSV()
        }
    }

    var summaryCard: some View {

        VStack(alignment: .leading, spacing: 10) {

            Text(loads.first?.driverName ?? "Unknown")
                .font(.largeTitle.bold())
            
            Text(
                settings?.truckingCompanyName
                ?? "Trucking Company"
            )
            .font(.headline)
            .foregroundStyle(.blue)

            Text("Truck \(loads.first?.truck ?? "-")")
                .foregroundStyle(.secondary)

            Divider()

            HStack {

                VStack(alignment: .leading) {

                    Text("Loads")
                        .font(.caption)

                    Text("\(loads.count)")
                        .font(.title.bold())
                }

                Spacer()

                VStack(alignment: .leading) {

                    Text(
                        "\(settings?.pickupCompanyName ?? "Pickup") Tons"
                    )
                        .font(.caption)

                    Text(
                        "\(loads.reduce(0) { $0 + $1.pickupTons }, specifier: "%.0f")"
                    )
                    .font(.title.bold())
                }

                Spacer()

                VStack(alignment: .leading) {

                    Text(
                        "\(settings?.dropoffCompanyName ?? "Dropoff") Tons"
                    )
                        .font(.caption)

                    Text(
                        "\(loads.filter { $0.isDelivered }.reduce(0) { $0 + $1.deliveryTons }, specifier: "%.0f")"
                    )
                    .font(.title.bold())
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }
    
    func formatTime(_ value: String) -> String {

        if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "-"
        }

        return value
    }
    
    func calculateDuration(
        pickup: String,
        delivered: String
    ) -> String {

        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"

        let cleanedPickup = pickup
            .replacingOccurrences(of: " ", with: " ")

        let cleanedDelivered = delivered
            .replacingOccurrences(of: " ", with: " ")

        guard
            let pickupDate = formatter.date(from: cleanedPickup),
            let deliveredDate = formatter.date(from: cleanedDelivered)
        else {
            return "-"
        }

        let seconds = deliveredDate.timeIntervalSince(pickupDate)

        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60

        return "\(hours)h \(minutes)m"
    }
    
    func durationText(
        pickup: String,
        delivered: String
    ) -> String {

        let formatter = ISO8601DateFormatter()

        guard
            let pickupDate = formatter.date(from: pickup),
            let deliveredDate = formatter.date(from: delivered)
        else {
            return "Unknown"
        }

        let seconds = deliveredDate.timeIntervalSince(pickupDate)

        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60

        return "\(hours)h \(minutes)m"
    }
    
    func formattedTimestamp(_ value: String) -> String {

        let isoFormatter = ISO8601DateFormatter()

        guard let date = isoFormatter.date(from: value) else {
            return value
        }

        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .medium

        return formatter.string(from: date)
    }

    func parseCSV() {

        do {

            let text = try String(
                contentsOf: fileURL,
                encoding: .utf8
            )

            let rows = text.components(separatedBy: "\n")
                .dropFirst()

            var parsed: [CSVLoad] = []

            for row in rows {

                let columns = row.components(separatedBy: ",")

                if columns.count < 11 {
                    continue
                }

                let load = CSVLoad(
                    date: columns[0],
                    time: columns[1],

                    driverName: columns[2]
                        .replacingOccurrences(of: "\"", with: ""),

                    truck: columns[3],

                    pickupTicket: columns[4]
                        .replacingOccurrences(of: "\"", with: ""),

                    pickupTons: Double(columns[5]) ?? 0,

                    deliveryTicket: columns[6]
                        .replacingOccurrences(of: "\"", with: ""),

                    deliveryTons: Double(columns[7]) ?? 0,

                    pickedUp: columns[8],
                    delivered: columns[9]
                )

                parsed.append(load)
            }

            loads = parsed

        } catch {

            print("❌ Failed parsing CSV:", error)
        }
    }
}
