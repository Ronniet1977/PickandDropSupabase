import Foundation

struct CloseWeekArchiveExporter {
    
    static func archiveFolder() -> URL {
        let folder = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PickandDrop")
            .appendingPathComponent("Archives")
        
        try? FileManager.default.createDirectory(
            at: folder,
            withIntermediateDirectories: true
        )
        
        return folder
    }
    
    static func appendLoads(
        loads: [SupabaseLoad],
        settings: SupabaseCompanySettings?
    ) {
        let url = archiveFolder()
            .appendingPathComponent("Load_Archive.csv")
        
        let completedLoads = loads.filter {
            $0.status == "delivered" &&
            $0.is_archived != true
        }
        
        let needsHeader =
        !FileManager.default.fileExists(atPath: url.path)
        
        var csv = ""
        
        if needsHeader {
            csv += "Archived At,Driver,Truck,Pickup Ticket,Pickup Tons,Delivery Ticket,Delivery Tons,Status,Picked Up At,Delivered At\n"
        }
        
        for load in completedLoads {
            
            csv += [
                csvSafe(Date().formatted()),
                csvSafe(load.driver_name ?? ""),
                csvSafe(load.truck_number ?? ""),
                csvSafe(load.pickup_ticket_number ?? ""),
                String(format: "%.2f", load.pickup_tons ?? 0),
                csvSafe(load.delivery_ticket_number ?? ""),
                String(format: "%.2f", load.delivery_tons ?? 0),
                csvSafe(load.status ?? ""),
                csvSafe(load.picked_up_at ?? ""),
                csvSafe(load.delivered_at ?? "")
            ].joined(separator: ",") + "\n"
        }
        
        append(csv, to: url)
    }
    
    static func appendFuel(
        fuel: [SupabaseFuel]
    ) {
        let url = archiveFolder()
            .appendingPathComponent("Fuel_Archive.csv")
        
        let needsHeader =
        !FileManager.default.fileExists(atPath: url.path)
        
        var csv = ""
        
        if needsHeader {
            csv += "Archived At,Driver,Truck,Amount,Created At,Receipt Saved\n"
        }
        
        for entry in fuel {
            csv += [
                csvSafe(Date().formatted()),
                csvSafe(entry.driver_name ?? ""),
                csvSafe(entry.truck_number ?? ""),
                String(format: "%.2f", entry.amount ?? 0),
                csvSafe(entry.created_at ?? ""),
                entry.receipt_path == nil ? "true" : "false"
            ].joined(separator: ",") + "\n"
        }
        
        append(csv, to: url)
    }
    
    static func append(_ text: String, to url: URL) {
        if let handle = try? FileHandle(forWritingTo: url) {
            _ = try? handle.seekToEnd()
            if let data = text.data(using: .utf8) {
                try? handle.write(contentsOf: data)
            }
            try? handle.close()
        } else {
            try? text.write(
                to: url,
                atomically: true,
                encoding: .utf8
            )
        }
        
        print("✅ Archived CSV:", url.lastPathComponent)
    }
    
    static func csvSafe(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}

