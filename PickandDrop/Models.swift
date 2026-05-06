import SwiftUI
import Foundation
import SwiftData
import Foundation

struct ReportLoadItem: Identifiable {
    let id = UUID()
    
    var driverName: String
    var truck: String
    
    var pickupCompany: String
    var pickupTicketNumber: String
    var pickupTons: Double
    
    var deliveryCompany: String
    var deliveryTicketNumber: String
    var deliveryTons: Double
}

struct DriverSummary: Identifiable {
    var id: String { name }   // stable ID
    
    var name: String
    var truck: String
    var loads: Int
    var tons: Double
    var fuel: Double
    var status: String
}

@Model
class DriverProfile {
    var name: String = ""
    var truckNumber: String = ""
    var role: String = "driver"
    
    init() {}
}

@Model
class Shift {
    var driverName: String = ""
    var startedAt: Date = Date()
    var endedAt: Date? = nil
    var fuelTotal: Double = 0
    var status: String = "active"
    
    init() {}
}

@Model
class LoadItem {
    var driverName: String = ""
    
    var pickupCompany: String = "BRC"
    var pickupTicketNumber: String = ""
    var pickupTons: Double = 0
    var pickedUpAt: Date? = nil
    
    var deliveryCompany: String = "HoneyGo"
    var deliveryTicketNumber: String = ""
    var deliveryTons: Double = 0
    var deliveredAt: Date? = nil
    
    var status: String = "new" // new, pickedUp, delivered
    var createdAt: Date = Date()
    
    init() {}
}
