import SwiftUI
import Foundation
import SwiftData
import Foundation


struct SupabaseCompanySettings: Codable, Identifiable {
    let id: UUID

    let trucking_company_name: String
    let pickup_company_name: String
    let dropoff_company_name: String
    let company_join_code: String
    let rate_per_ton: Double
}

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

    var username: String = ""
    var password: String = ""
    
    var role: String = "driver"

    var isActive: Bool = true
    
    var mustChangePassword: Bool = true

    init() {}
}

@Model
class Shift {
    var id: UUID = UUID()
    
    var driverName: String = ""
    var companyName: String = ""
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
    
    var truckingCompanyName: String = ""
    var pickupCompanyName: String = ""
    var dropoffCompanyName: String = ""
    
    var isArchived: Bool = false

    init() {}
}
