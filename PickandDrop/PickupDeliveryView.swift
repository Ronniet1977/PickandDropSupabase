import SwiftUI
import SwiftData
import UserNotifications

struct PickupDeliveryView: View {
    let driver: DriverProfile
    
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query var loads: [LoadItem]
    @Query var shifts: [Shift]
    @Query var companySettings: [CompanySettings]
    
    @StateObject private var notificationManager = NotificationSyncManager()
    @State private var deliveryTicket = ""
    @State private var deliveryTons = ""
    
    @State private var supabaseLoads: [SupabaseLoad] = []
    @State private var selectedLoad: SupabaseLoad?
    
    var settings: CompanySettings? {
        companySettings.first
    }
    
    
    var activeShift: Shift? {
        shifts.first {
            $0.driverName == driver.name && $0.status == "active"
        }
    }
    
    var driverLoads: [SupabaseLoad] {
        supabaseLoads
            .filter {
                $0.driver_name == driver.name &&
                $0.is_archived != true
            }
            .sorted {
                if $0.delivered_at == nil && $1.delivered_at != nil {
                    return true
                }

                if $0.delivered_at != nil && $1.delivered_at == nil {
                    return false
                }

                return ($0.created_at ?? "") > ($1.created_at ?? "")
            }
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

                LazyVStack(spacing: 20) {
                    VStack(spacing: 6) {

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
                        .foregroundStyle(.secondary)
                    }
                    .padding(.bottom, 8)

                    if driverLoads.isEmpty {

                        Text("No loads yet")
                            .foregroundStyle(.white.opacity(0.7))
                            .padding(.top, 40)
                    }

                    ForEach(driverLoads) { load in

                        VStack(alignment: .leading, spacing: 14) {

                            HStack(alignment: .top) {

                                VStack(alignment: .leading, spacing: 6) {

                                    let ticket = load.pickup_ticket_number ?? ""

                                    Text("Ticket: \(ticket)")
                                        .font(.title3.bold())
                                        .foregroundStyle(.white)

                                    let tons = load.pickup_tons ?? 0

                                    Text("Tons: \(tons, specifier: "%.2f")")
                                        .font(.subheadline)
                                        .foregroundStyle(.white.opacity(0.7))

                                    if let picked = load.picked_up_at {
                                        Text("Picked up: \(picked)")
                                            .font(.caption)
                                            .foregroundStyle(.orange)
                                    }

                                    if let delivered = load.delivered_at {
                                        Text("Delivered: \(delivered)")
                                            .font(.caption)
                                            .foregroundStyle(.green)
                                    }
                                }

                                Spacer()

                                //Text(statusText(load.status ?? "pickedUp"))
                                    //.font(.caption.bold())
                                    //.padding(.horizontal, 12)
                                    //.padding(.vertical, 8)
                                    //.background(
                                        //statusColor(load.status ?? "pickedUp").opacity(0.2)
                                    //)
                                    //.foregroundStyle(
                                        //statusColor(load.status ?? "pickedUp")
                                    //)
                                    //.clipShape(Capsule())
                            }

                            HStack(spacing: 14) {

                                Button(
                                    "Deliver (\(settings?.dropoffCompanyName ?? "Dropoff"))"
                                ) {

                                    deliveryTicket = ""
                                    deliveryTons = ""

                                    selectedLoad = load
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.green)
                                .disabled(
                                    load.picked_up_at == nil ||
                                    load.delivered_at != nil
                                )
                            }
                        }
                        .padding(20)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 28))
                        .overlay(
                            RoundedRectangle(cornerRadius: 28)
                                .stroke(.white.opacity(0.08))
                        )
                    }
                }
                .padding()
            }
        }
        .navigationTitle(
            "\(settings?.pickupCompanyName ?? "Pickup") → \(settings?.dropoffCompanyName ?? "Dropoff")"
        )
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .onAppear {
            requestNotificationPermission()

            Task {
                supabaseLoads =
                    await LoadSupabaseManager.shared.fetchLoads()
            }
        }
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

                    VStack(spacing: 28) {

                        Spacer()

                        VStack(spacing: 18) {

                            ZStack {

                                Circle()
                                    .fill(.green.opacity(0.15))
                                    .frame(width: 110, height: 110)

                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 58))
                                    .foregroundStyle(.green)
                            }

                            Text("Complete Delivery")
                                .font(.system(size: 34, weight: .bold))
                                .foregroundStyle(.white)

                            Text(
                                "\(settings?.pickupCompanyName ?? "Pickup") Ticket \(load.pickup_ticket_number ?? "")"
                            )
                            .foregroundStyle(.white.opacity(0.7))
                        }

                        VStack(spacing: 18) {

                            VStack(alignment: .leading, spacing: 8) {

                                Text(
                                    "\(settings?.dropoffCompanyName ?? "Dropoff") Ticket"
                                )
                                .font(.caption.bold())
                                .foregroundStyle(.white.opacity(0.7))

                                TextField(
                                    "Enter Ticket Number",
                                    text: $deliveryTicket
                                )
                                .textFieldStyle(.plain)
                                .padding()
                                .background(.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 18))
                                .foregroundStyle(.white)
                            }

                            VStack(alignment: .leading, spacing: 8) {

                                Text(
                                    "\(settings?.dropoffCompanyName ?? "Dropoff") Tons"
                                )
                                .font(.caption.bold())
                                    .foregroundStyle(.white.opacity(0.7))

                                TextField(
                                    "Enter Tons",
                                    text: $deliveryTons
                                )
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.plain)
                                .padding()
                                .background(.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 18))
                                .foregroundStyle(.white)
                            }
                        }
                        .padding(24)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 30))
                        .padding(.horizontal)

                        Button {
                            Task {
                                await completeDelivery(load)
                            }
                        } label: {

                            HStack {

                                Image(systemName: "checkmark.circle.fill")

                                Text("Complete Delivery")
                                    .fontWeight(.bold)
                            }
                            .font(.title3)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.green.gradient)
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                        }
                        .padding(.horizontal)

                        Spacer()
                    }
                    .padding()
                }
                .toolbar {

                    ToolbarItem(placement: .topBarTrailing) {

                        Button("Close") {
                            selectedLoad = nil
                        }
                        .foregroundStyle(.white)
                    }
                }
            }
        }
    }
    
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("✅ Notifications allowed")
            } else {
                print("❌ Notifications denied:", error?.localizedDescription ?? "Unknown")
            }
        }
    }
    
    func sendAdminNotification(
        type: String,
        message: String,
        ticket: String? = nil
    ) {
        let note = AppNotification(
            type: type,
            driverName: driver.name,
            truckNumber: driver.truckNumber,
            message: message,
            loadTicket: ticket
        )

        notificationManager.sendNotification(note)
    }
    
    func completeDelivery(_ load: SupabaseLoad) async {
        guard let tonsValue = Double(deliveryTons) else { return }

        await LoadSupabaseManager.shared.deliverLoad(
            loadID: load.id,
            deliveryTicketNumber: deliveryTicket,
            deliveryTons: tonsValue
        )

        sendAdminNotification(
            type: "Delivered",
            message: "\(driver.name) delivered \(settings?.dropoffCompanyName ?? "Dropoff") ticket \(deliveryTicket) • \(tonsValue) tons",
            ticket: deliveryTicket
        )

        await MainActor.run {
            deliveryTicket = ""
            deliveryTons = ""
            selectedLoad = nil
        }

        supabaseLoads =
            await LoadSupabaseManager.shared.fetchLoads()
    }
    
    func statusText(_ status: String) -> String {
        switch status {
        case "pickedUp": return "Picked Up"
        case "delivered": return "Delivered"
        default: return "New"
        }
    }
    
    func statusColor(_ status: String) -> Color {
        switch status {
        case "pickedUp": return .orange
        case "delivered": return .green
        default: return .gray
        }
    }
}
