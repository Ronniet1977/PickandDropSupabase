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
    let fuel_surcharge_per_ton: Double
}

struct SupabaseAppConfig: Codable {
    let minimum_version: String
    let latest_version: String
    let minimum_build: Int
    let latest_build: Int
    let force_update: Bool
    let app_store_url: String?
}

struct SupabaseDriver: Codable, Identifiable {

    let id: UUID

    let name: String
    let username: String
    let must_change_password: Bool?
    let truck_number: String

    let role: String
    let is_active: Bool

    let duty_status: String?

    let auth_user_id: UUID?
}

struct SupabaseLoad: Codable, Identifiable {

    let id: UUID

    let driver_name: String?

    let truck_number: String?

    let pickup_ticket_number: String?
    let delivery_ticket_number: String?

    let pickup_tons: Double?
    let delivery_tons: Double?

    let status: String?

    let picked_up_at: String?
    let delivered_at: String?

    let created_at: String?

    let is_archived: Bool?
    let rate_per_ton: Double?
    let fuel_surcharge_per_ton: Double?
}

struct SupabaseFuel: Codable, Identifiable {
    let id: UUID
    let driver_name: String?
    let truck_number: String?
    let amount: Double?
    let created_at: String?
    let receipt_path: String?
    let is_archived: Bool?
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
