import SwiftUI
import Foundation

struct CSVExporter {
    
    static func generateCSV(
        loads: [LoadItem],
        driver: DriverProfile,
        activeShift: Shift?,
        settings: CompanySettings?,
        isFinal: Bool = false
    ) -> URL {
        
        func csvSafe(_ value: String) -> String {
            "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        
        var csv = "Date,Time,Driver,Truck,\(settings?.pickupCompanyName ?? "Pickup") Ticket,\(settings?.pickupCompanyName ?? "Pickup") Tons,\(settings?.dropoffCompanyName ?? "Dropoff") Ticket,\(settings?.dropoffCompanyName ?? "Dropoff") Tons,PickedUp,Delivered,Fuel Total\n"
        
        let safeName = driver.name
            .replacingOccurrences(of: "[^a-zA-Z0-9_-]", with: "_", options: .regularExpression)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        
        let sortedLoads = loads.sorted {
            $0.createdAt < $1.createdAt
        }
        
        let fileFormatter = DateFormatter()
        fileFormatter.dateFormat = "yyyy-MM-dd_HH-mm"
        
        let suffix = isFinal
            ? "FINAL-\(fileFormatter.string(from: Date()))"
            : "ACTIVE"
        
        let fileName = "\(safeName)-Truck\(driver.truckNumber)-\(suffix).csv"
        
        if sortedLoads.isEmpty {

            let date = dateFormatter.string(from: Date())
            let time = timeFormatter.string(from: Date())
            let fuelString = String(format: "%.2f", activeShift?.fuelTotal ?? 0)

            csv += "\(date),\(time),\(csvSafe(driver.name)),\(driver.truckNumber),,,,,,,\(fuelString)\n"
        }
        
        for (index, load) in sortedLoads.enumerated() {

            print("🚚 CSV LOAD:", load.pickupTicketNumber)
            print("🚚 DELIVERED:", load.deliveredAt != nil)

            let date = dateFormatter.string(from: load.createdAt)
            let time = timeFormatter.string(from: load.createdAt)
            
            let isLast = index == sortedLoads.indices.last
            let fuel = isLast ? (activeShift?.fuelTotal ?? 0) : 0
            
            let pickupTons = String(format: "%.2f", load.pickupTons)

            let deliveryTons = String(format: "%.2f", load.deliveryTons)
            let fuelString = String(format: "%.2f", fuel)
            
            // 🔥 Format timestamps safely
            let pickedUp = load.pickedUpAt
                .map { ISO8601DateFormatter().string(from: $0) }
                ?? "Not picked up"
            
            let delivered = load.deliveredAt
                .map { ISO8601DateFormatter().string(from: $0) } ?? ""
            
            csv += "\(date),\(time),\(csvSafe(driver.name)),\(driver.truckNumber),\(csvSafe(load.pickupTicketNumber)),\(pickupTons),\(csvSafe(load.deliveryTicketNumber)),\(deliveryTons),\(pickedUp),\(delivered),\(fuelString)\n"
        }
        
        let url = StorageManager
            .truckReportsFolder()
            .appendingPathComponent(fileName)
        
        do {
            let data = Data(csv.utf8)

            try data.write(
                to: url,
                options: .atomic
            )
            print("✅ CSV written:", url)
            
        } catch {
            print("❌ CSV write failed:", error)
        }
        
        return url
    }
    
    static func deleteActiveCSV(driver: DriverProfile) {

        let safeName = driver.name
            .replacingOccurrences(
                of: "[^a-zA-Z0-9_-]",
                with: "_",
                options: .regularExpression
            )

        let fileName = "\(safeName)-Truck\(driver.truckNumber)-ACTIVE.csv"

        let url = StorageManager
            .truckReportsFolder()
            .appendingPathComponent(fileName)

        if FileManager.default.fileExists(atPath: url.path) {

            try? FileManager.default.removeItem(at: url)

            print("🗑 ACTIVE removed:", fileName)
        }
    }
}

