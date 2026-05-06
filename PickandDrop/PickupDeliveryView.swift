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
        List {
            if driverLoads.isEmpty {
                Text("No loads yet")
                    .foregroundStyle(.secondary)
            }
            
            ForEach(driverLoads) { load in
                VStack(alignment: .leading, spacing: 10) {
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            
                            // ✅ Ticket (correct field)
                            Text("Ticket: \(load.pickupTicketNumber)")
                                .font(.headline)
                            
                            // ✅ Tons
                            Text("Tons: \(String(format: "%.2f", load.pickupTons))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            // ✅ Picked up time
                            if let picked = load.pickedUpAt {
                                Text("Picked up: \(picked.formatted(date: .omitted, time: .shortened))")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }
                            
                            // ✅ Delivered time
                            if let delivered = load.deliveredAt {
                                Text("Delivered: \(delivered.formatted(date: .omitted, time: .shortened))")
                                    .font(.caption2)
                                    .foregroundStyle(.green)
                            }
                        }
                        
                        Spacer()
                        
                        Text(statusText(load.status))
                            .font(.caption.bold())
                            .padding(6)
                            .background(statusColor(load.status).opacity(0.2))
                            .foregroundStyle(statusColor(load.status))
                            .clipShape(Capsule())
                    }
                    
                    // 🔥 ACTION BUTTONS
                    HStack {
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
                        .disabled(load.pickedUpAt == nil || load.deliveredAt != nil)
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .navigationTitle("Pickup / Deliver")
        .onAppear {
            requestNotificationPermission()
        }
        .sheet(item: $selectedLoad) { load in
            NavigationStack {
                Form {
                    Section("Delivery (HoneyGo)") {
                        TextField("HoneyGo Ticket Number", text: $deliveryTicket)
                        
                        TextField("HoneyGo Tons", text: $deliveryTons)
                            .keyboardType(.decimalPad)
                    }
                    
                    Button("Complete Delivery") {
                        completeDelivery(load)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .navigationTitle("Deliver Load")
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
            
            DispatchQueue.global(qos: .background).async {
                let _ = CSVExporter.generateCSV(
                    loads: driverLoads,
                    driver: driver,
                    activeShift: currentShift
                )
            }
            
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
