import SwiftUI
import SwiftData
import UserNotifications

struct PickupDeliveryView: View {
    let driver: DriverProfile
    
    @Environment(\.modelContext) private var context
    @Query var loads: [LoadItem]
    @Query var shifts: [Shift]
    @Query var companySettings: [CompanySettings]
    
    @State private var selectedLoad: LoadItem?
    @State private var deliveryTicket = ""
    @State private var deliveryTons = ""
    
    var settings: CompanySettings? {
        companySettings.first
    }
    
    
    var activeShift: Shift? {
        shifts.first {
            $0.driverName == driver.name && $0.status == "active"
        }
    }
    
    var driverLoads: [LoadItem] {
        loads
            .filter {
                $0.driverName == driver.name &&
                !$0.isArchived
            }
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

                                    Text("Ticket: \(load.pickupTicketNumber)")
                                        .font(.title3.bold())
                                        .foregroundStyle(.white)

                                    Text("Tons: \(String(format: "%.2f", load.pickupTons))")
                                        .font(.subheadline)
                                        .foregroundStyle(.white.opacity(0.7))

                                    if let picked = load.pickedUpAt {

                                        Text(
                                            "Picked up: \(picked.formatted(date: .omitted, time: .shortened))"
                                        )
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                    }

                                    if let delivered = load.deliveredAt {

                                        Text(
                                            "Delivered: \(delivered.formatted(date: .omitted, time: .shortened))"
                                        )
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                    }
                                }

                                Spacer()

                                Text(statusText(load.status))
                                    .font(.caption.bold())
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        statusColor(load.status).opacity(0.2)
                                    )
                                    .foregroundStyle(statusColor(load.status))
                                    .clipShape(Capsule())
                            }

                            HStack(spacing: 14) {

                                Button(
                                    "Pickup (\(settings?.pickupCompanyName ?? "Pickup"))"
                                ) {
                                    markPickedUp(load)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.blue)
                                .disabled(load.pickedUpAt != nil)

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
                                    load.pickedUpAt == nil ||
                                    load.deliveredAt != nil
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
                                "\(settings?.pickupCompanyName ?? "Pickup") Ticket \(load.pickupTicketNumber)"
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

                            completeDelivery(load)

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
    
    func sendDeliveryNotification(for load: LoadItem) {
        let content = UNMutableNotificationContent()
        content.title =
            "\(settings?.dropoffCompanyName ?? "Dropoff") Load Delivered ✅"
        content.body =
            "\(driver.name) delivered \(settings?.dropoffCompanyName ?? "Dropoff") ticket \(load.deliveryTicketNumber)"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Notification failed:", error)
            } else {
                print("✅ Delivery notification sent")
            }
        }
    }
    
    func markPickedUp(_ load: LoadItem) {
        load.status = "pickedUp"
        load.pickedUpAt = Date()
        saveAndUpdateCSV()
    }
    
    func completeDelivery(_ load: LoadItem) {
        guard let tonsValue = Double(deliveryTons) else { return }
        
        // ✅ Mark delivered
        load.deliveredAt = Date()
        load.status = "delivered"
        load.deliveryTicketNumber = deliveryTicket
        
        // ✅ Optional: update tons if you want
        load.deliveryTons = tonsValue
        
        sendDeliveryNotification(for: load)
        
        print("✅ DELIVERY SAVED:", load.deliveryTicketNumber)
        print("✅ DELIVERED AT:", load.deliveredAt ?? Date())
        
        saveAndUpdateCSV()
        
        deliveryTicket = ""
        deliveryTons = ""
        selectedLoad = nil
        
    }
    
    func saveAndUpdateCSV() {
        do {
            try context.save()

            let currentShift = activeShift

            let driverLoads = loads.filter {
                $0.driverName == driver.name &&
                !$0.isArchived
            }

            let _ = CSVExporter.generateCSV(
                loads: driverLoads,
                driver: driver,
                activeShift: currentShift,
                settings: settings
            )

            print("✅ Pickup/Deliver updated")

        } catch {
            print("❌ Pickup/Deliver save failed:", error)
        }
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
