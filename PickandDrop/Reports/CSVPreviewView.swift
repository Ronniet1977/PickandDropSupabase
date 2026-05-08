//
//  CSVPreviewView.swift
//  PickandDrop
//
//  Created by Ronald Thayer Jr on 5/7/26.
//

import SwiftUI

struct CSVPreviewView: View {

    let fileURL: URL

    @State private var loads: [CSVLoad] = []

    var body: some View {

        ScrollView {

            VStack(spacing: 16) {

                summaryCard

                ForEach(loads) { load in

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
                                    .foregroundStyle(.green)

                            } else {

                                Text("🟠 Picked Up")
                                    .foregroundStyle(.orange)
                            }
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 4) {

                            Text("Driver: \(load.driverName)")
                            Text("Truck: \(load.truck)")

                            if load.isDelivered {

                                Text("HoneyGo Ticket: \(load.deliveryTicket)")
                                    .foregroundStyle(.secondary)

                            } else {

                                Text("Not delivered yet")
                                    .foregroundStyle(.secondary)
                            }
                        }
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

                    Text("Delivered")

                    Text(
                        "\(loads.filter { $0.isDelivered }.count)"
                    )
                    .font(.title.bold())
                }
            }
        }
        .padding()
        .background(.white.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 24))
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
