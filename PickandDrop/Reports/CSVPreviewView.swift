//
//  CSVPreviewView.swift
//  PickandDrop
//
//  Created by Ronald Thayer Jr on 5/7/26.
//

import SwiftUI

struct CSVPreviewView: View {

    let fileURL: URL
    let generatePickupInvoice: (URL) -> Void
    let generateDeliveryInvoice: (URL) -> Void

    @State private var loads: [CSVLoad] = []

    var body: some View {

        ScrollView {

            VStack(spacing: 16) {

                summaryCard

                ForEach(loads, id: \.id) { load in

                    VStack(alignment: .leading, spacing: 10) {

                        HStack {

                            VStack(alignment: .leading) {

                                Text("Ticket \(load.pickupTicket)")
                                    .font(.headline)

                                Text("\(load.pickupTons, specifier: "%.0f") tons")
                                    .foregroundStyle(.blue)
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
                            Text("BRC → HoneyGo")
                                .font(.caption.bold())
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(.blue.opacity(0.15))
                                .foregroundStyle(.blue)
                                .clipShape(Capsule())

                            Divider()

                            Text("BRC Ticket: \(load.pickupTicket)")
                                .foregroundStyle(.secondary)

                            if load.isDelivered {

                                Text("HoneyGo Ticket: \(load.deliveryTicket)")
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

                                    Button("BRC Invoice") {
                                        generatePickupInvoice(fileURL)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.blue)

                                    Button("HoneyGo Invoice") {
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
                    .background(.white.opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                }
            }
            .padding()
        }
        .background(
            LinearGradient(
                colors: [.blue.opacity(0.3), .black.opacity(0.1)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .navigationTitle(fileURL.lastPathComponent)
        .onAppear {
            parseCSV()
        }
    }

    var summaryCard: some View {

        VStack(alignment: .leading, spacing: 10) {

            Text(loads.first?.driverName ?? "Unknown")
                .font(.largeTitle.bold())

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

                    Text("Pickup Tons")
                        .font(.caption)

                    Text(
                        "\(loads.reduce(0) { $0 + $1.pickupTons }, specifier: "%.0f")"
                    )
                    .font(.title.bold())
                }

                Spacer()

                VStack(alignment: .leading) {

                    Text("Delivered Tons")
                        .font(.caption)

                    Text(
                        "\(loads.filter { $0.isDelivered }.reduce(0) { $0 + $1.deliveryTons }, specifier: "%.0f")"
                    )
                    .font(.title.bold())
                }
            }
        }
        .padding()
        .background(.white.opacity(0.95))
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
