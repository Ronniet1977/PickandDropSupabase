import SwiftUI
import Foundation
import SwiftData
import Foundation

struct DriverSummary: Identifiable {
    var id: String { name }   // stable ID
    
    var name: String
    var truck: String
    var loads: Int
    var pickupTons: Double
    var deliveryTons: Double
    var fuel: Double
    var status: String
    
    var isFinished: Bool
}

@Model
class DriverProfile {
    var name: String = ""
    var truckNumber: String = ""
    var role: String = "driver"
    
    init() {}   // ✅ REQUIRED
}

@Model
class Shift {
    var id: UUID = UUID()
    
    var driverName: String = ""
    var startedAt: Date = Date()
    var endedAt: Date? = nil
    
    var fuelTotal: Double = 0
    var status: String = "active"
    
    @Relationship(deleteRule: .cascade)
    var loads: [LoadItem]? = []
    
    init() {}   // ✅ REQUIRED
}

@Model
class LoadItem {

    var id: UUID = UUID()

    var driverName: String = ""
    var pickupTicketNumber: String = ""
    var deliveryTicketNumber: String = ""
    var pickupTons: Double = 0
    var deliveryTons: Double = 0

    var pickedUpAt: Date? = nil
    var deliveredAt: Date? = nil

    var status: String = "new"
    var createdAt: Date = Date()

    var shift: Shift? = nil

    // ✅ Computed (clean + safe)
    var isPickedUp: Bool { pickedUpAt != nil }
    var isDelivered: Bool { deliveredAt != nil }

    init() {}
}
