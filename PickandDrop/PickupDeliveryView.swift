import SwiftUI
import SwiftData
import UserNotifications

struct PickupDeliveryView: View {
    let driver: DriverProfile
    
    @Environment(\.modelContext) private var context
    @Query var loads: [LoadItem]
    @Query var shifts: [Shift]
    
    @State private var selectedLoad: LoadItem?
    @State private var deliveryTicket = ""
    @State private var deliveryTons = ""
    
    
    var activeShift: Shift? {
        shifts.first {
            $0.driverName == driver.name && $0.status == "active"
        }
    }
    
    var driverLoads: [LoadItem] {
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

                LazyVStack(spacing: 20) {

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

                                Button("Pickup (BRC)") {
                                    markPickedUp(load)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.blue)
                                .disabled(load.pickedUpAt != nil)

                                Button("Deliver (HoneyGo)") {

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
        .navigationTitle("Pickup / Deliver")
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

                            Text("Ticket \(load.pickupTicketNumber)")
                                .foregroundStyle(.white.opacity(0.7))
                        }

                        VStack(spacing: 18) {

                            VStack(alignment: .leading, spacing: 8) {

                                Text("HoneyGo Ticket")
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

                                Text("Delivered Tons")
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
        content.title = "Load Delivered ✅"
        content.body = "\(driver.name) delivered HoneyGo ticket \(load.deliveryTicketNumber)"
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
        
        saveAndUpdateCSV()
        
        deliveryTicket = ""
        deliveryTons = ""
        selectedLoad = nil
    }
    
    func saveAndUpdateCSV() {
        do {
            try context.save()

            let driverLoads = loads.filter {
                $0.driverName == driver.name
            }

            let currentShift = activeShift

            let _ = CSVExporter.generateCSV(
                loads: driverLoads,
                driver: driver,
                activeShift: currentShift
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
