import SwiftUI
import SwiftData

struct LoadListView: View {
    let driver: DriverProfile
    
    @Environment(\.modelContext) private var context
    @Query var loads: [LoadItem]
    @Query var companySettings: [CompanySettings]
    
    var settings: CompanySettings? {
        companySettings.first
    }
    
    var shiftLoads: [LoadItem] {
        loads
            .filter { $0.driverName == driver.name }
            .sorted { $0.createdAt > $1.createdAt }
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

                VStack(spacing: 24) {

                    // HEADER CARD

                    VStack(alignment: .leading, spacing: 18) {
                        Text(
                            settings?.truckingCompanyName
                            ?? "Trucking Company"
                        )
                        .font(.caption.bold())
                        .foregroundStyle(.blue)

                        Text(driver.name)
                            .font(.largeTitle.bold())
                            .foregroundStyle(.white)

                        Text("Truck \(driver.truckNumber)")
                            .foregroundStyle(.white.opacity(0.7))

                        Divider()

                        let pickupTons = shiftLoads.reduce(0) {
                            $0 + $1.pickupTons
                        }

                        let deliveredTons = shiftLoads.reduce(0) {
                            $0 + $1.deliveryTons
                        }

                        let remainingTons = pickupTons - deliveredTons

                        HStack {

                            loadStat(
                                title: "Loads",
                                value: "\(shiftLoads.count)"
                            )

                            Spacer()

                            loadStat(
                                title: settings?.pickupCompanyName ?? "Pickup",
                                value: String(format: "%.0f", pickupTons)
                            )

                            Spacer()

                            loadStat(
                                title: settings?.dropoffCompanyName ?? "Dropoff",
                                value: String(format: "%.0f", deliveredTons)
                            )

                            Spacer()

                            loadStat(
                                title: "Remaining",
                                value: String(format: "%.0f", remainingTons)
                            )
                        }
                    }
                    .padding(24)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 30))

                    // EMPTY STATE

                    if shiftLoads.isEmpty {

                        VStack(spacing: 16) {

                            Image(systemName: "shippingbox")
                                .font(.system(size: 54))
                                .foregroundStyle(.gray)

                            Text("No Loads Yet")
                                .font(.title2.bold())
                                .foregroundStyle(.white)

                            Text("Loads added during your shift will appear here.")
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .padding(.top, 80)
                    }

                    // LOAD CARDS

                    ForEach(shiftLoads, id: \.id) { load in

                        VStack(alignment: .leading, spacing: 16) {

                            HStack {

                                VStack(alignment: .leading, spacing: 6) {

                                    Text(
                                        "\(settings?.pickupCompanyName ?? "Pickup") Ticket \(load.pickupTicketNumber)"
                                    )
                                    .font(.title3.bold())
                                    .foregroundStyle(.white)

                                    HStack(spacing: 14) {

                                        Label(
                                            "\(String(format: "%.2f", load.pickupTons)) \(settings?.pickupCompanyName ?? "Pickup") Tons",
                                            systemImage: "arrow.up.circle.fill"
                                        )
                                        .foregroundStyle(.blue)

                                        if load.isDelivered {

                                            Label(
                                                "\(String(format: "%.2f", load.deliveryTons)) \(settings?.dropoffCompanyName ?? "Dropoff") Tons",
                                                systemImage: "arrow.down.circle.fill"
                                            )
                                            .foregroundStyle(.orange)
                                        }
                                    }
                                    .font(.subheadline.bold())
                                }

                                Spacer()

                                Text(load.isDelivered ? "Delivered" : "Picked Up")
                                    .font(.caption.bold())
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        load.isDelivered
                                        ? .green.opacity(0.2)
                                        : .orange.opacity(0.2)
                                    )
                                    .foregroundStyle(
                                        load.isDelivered
                                        ? .green
                                        : .orange
                                    )
                                    .clipShape(Capsule())
                            }

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

                            VStack(alignment: .leading, spacing: 8) {

                                if let picked = load.pickedUpAt {

                                    Label(
                                        picked.formatted(
                                            date: .omitted,
                                            time: .shortened
                                        ),
                                        systemImage: "clock.fill"
                                    )
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                                }

                                if let delivered = load.deliveredAt {

                                    Label(
                                        delivered.formatted(
                                            date: .omitted,
                                            time: .shortened
                                        ),
                                        systemImage: "checkmark.circle.fill"
                                    )
                                    .font(.caption)
                                    .foregroundStyle(.green)
                                }

                                if let picked = load.pickedUpAt,
                                   let delivered = load.deliveredAt {

                                    let duration = delivered.timeIntervalSince(picked)

                                    let hours = Int(duration) / 3600
                                    let minutes = (Int(duration) % 3600) / 60

                                    Text("Duration: \(hours)h \(minutes)m")
                                        .font(.caption.bold())
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                        .padding(22)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 28))
                        .overlay(
                            RoundedRectangle(cornerRadius: 28)
                                .stroke(.white.opacity(0.08))
                        )
                        .contextMenu {

                            Button(role: .destructive) {

                                context.delete(load)
                                try? context.save()

                            } label: {

                                Label(
                                    "Delete Load",
                                    systemImage: "trash"
                                )
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle(
            "\(settings?.pickupCompanyName ?? "Pickup") Loads"
        )
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }
    
    func loadStat(
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
    
    func deleteLoad(at offsets: IndexSet) {
        for index in offsets {
            context.delete(shiftLoads[index])
        }
        try? context.save()
    }
}
