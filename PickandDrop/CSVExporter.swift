//
//  CSVExporter.swift
//  PickandDrop
//
//  Created by Ronald Thayer Jr on 5/2/26.
//
import SwiftUI
import Foundation

struct CSVExporter {
    
    static func generateCSV(
        loads: [LoadItem],
        driver: DriverProfile,
        activeShift: Shift?,
        isFinal: Bool = false
    ) -> URL {
        
        var csv = "Date,Time,Driver,Truck,PickupCompany,PickupTicket,PickupTons,DeliveryCompany,DeliveryTicket,DeliveryTons,Fuel Total\n"
        
        let safeName = driver.name
            .replacingOccurrences(of: "[^a-zA-Z0-9_-]", with: "_", options: .regularExpression)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        
        let sortedLoads = loads.sorted {
            $0.createdAt < $1.createdAt
        }
        
        let dateFormatterForFile = DateFormatter()
        dateFormatterForFile.dateFormat = "yyyy-MM-dd_HH-mm"
        
        let suffix = isFinal
        ? "FINAL-\(dateFormatterForFile.string(from: Date()))"
        : "ACTIVE"
        
        let fileName = "\(safeName)-Truck\(driver.truckNumber)-\(suffix).csv"
        
        for (index, load) in sortedLoads.enumerated() {
            
            let date = dateFormatter.string(from: load.createdAt)
            let time = timeFormatter.string(from: load.createdAt)
            
            let fuel = (index == sortedLoads.count - 1)
            ? (activeShift?.fuelTotal ?? 0)
            : 0
            
            csv += "\(date),\(time),\(driver.name),\(driver.truckNumber),\(load.pickupCompany),\(load.pickupTicketNumber),\(load.pickupTons),\(load.deliveryCompany),\(load.deliveryTicketNumber),\(load.deliveryTons),\(fuel)\n"
        }
        
        _ = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        let folder = StorageManager.truckReportsFolder()
        
        let url = folder.appendingPathComponent(fileName)
        
        do {
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
            
            try csv.write(to: url, atomically: true, encoding: .utf8)
            print("✅ CSV updated:", url)
            
        } catch {
            print("❌ CSV write failed:", error)
        }
        
        return url
    }
}


