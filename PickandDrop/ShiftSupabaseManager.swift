import Foundation

struct SupabaseShift: Codable, Identifiable {
    
    let id: UUID
    
    let driver_name: String
    let username: String
    let truck_number: String
    
    let started_at: String
    let ended_at: String?
    
    let status: String
    let created_at: String?
}

final class ShiftSupabaseManager {
    
    static let shared = ShiftSupabaseManager()
    
    private init() {}
    
    // MARK: - Fetch
    
    func fetchShifts() async -> [SupabaseShift] {
        
        do {
            
            let data =
            try await SupabaseRESTManager.shared.request(
                table: "pickdrop_shifts",
                query: "?select=*&order=started_at.desc"
            )
            
            let shifts =
            try JSONDecoder().decode(
                [SupabaseShift].self,
                from: data
            )
            
            print(
                "✅ Loaded shifts:",
                shifts.count
            )
            
            return shifts
            
        } catch {
            
            print(
                "❌ Failed loading shifts:",
                error
            )
            
            return []
        }
    }
    
    // MARK: - Legacy Shift Migration
    
    func uploadLegacyShift(
        _ shift: Shift,
        username: String,
        truckNumber: String
    ) async -> Bool {
        
        guard let endedAt = shift.endedAt else {
            return false
        }
        
        let formatter =
        ISO8601DateFormatter()
        
        let body: [String: Any] = [
            "id": shift.id.uuidString,
            "driver_name": shift.driverName,
            "username": username.lowercased(),
            "truck_number": truckNumber,
            "started_at":
                formatter.string(
                    from: shift.startedAt
                ),
            "ended_at":
                formatter.string(
                    from: endedAt
                ),
            "status": "finished"
        ]
        
        do {
            
            let bodyData =
            try JSONSerialization.data(
                withJSONObject: body
            )
            
            _ =
            try await SupabaseRESTManager.shared.request(
                table: "pickdrop_shifts",
                method: "POST",
                body: bodyData
            )
            
            print(
                "☁️ Migrated legacy shift:",
                shift.driverName,
                shift.startedAt
            )
            
            return true
            
        } catch {
            
            print(
                "❌ Legacy shift migration failed:",
                shift.driverName,
                error
            )
            
            return false
        }
    }
    
    // MARK: - Start Shift
    
    func startShift(
        driverName: String,
        username: String,
        truckNumber: String
    ) async -> SupabaseShift? {
        
        let now =
        ISO8601DateFormatter()
            .string(from: Date())
        
        let body: [String: Any] = [
            "driver_name": driverName,
            "username":
                username.lowercased(),
            "truck_number": truckNumber,
            "started_at": now,
            "status": "active"
        ]
        
        do {
            
            let bodyData =
            try JSONSerialization.data(
                withJSONObject: body
            )
            
            let data =
            try await SupabaseRESTManager.shared.request(
                table: "pickdrop_shifts",
                method: "POST",
                body: bodyData
            )
            
            let inserted =
            try JSONDecoder().decode(
                [SupabaseShift].self,
                from: data
            )
            
            guard let shift =
                    inserted.first
            else {
                print(
                    "❌ No shift returned after insert"
                )
                return nil
            }
            
            print(
                "✅ Supabase shift started"
            )
            
            return shift
            
        } catch {
            
            print(
                "❌ Failed starting Supabase shift:",
                error
            )
            
            return nil
        }
    }
    
    func finishActiveShift(
        username: String
    ) async -> Bool {
        
        let now =
        ISO8601DateFormatter()
            .string(from: Date())
        
        let body: [String: Any] = [
            "ended_at": now,
            "status": "finished"
        ]
        
        do {
            
            let bodyData =
            try JSONSerialization.data(
                withJSONObject: body
            )
            
            _ = try await SupabaseRESTManager.shared.request(
                table: "pickdrop_shifts",
                method: "PATCH",
                query:
                    "?username=eq.\(username.lowercased())&status=eq.active",
                body: bodyData
            )
            
            print("✅ Supabase shift finished")
            
            return true
            
        } catch {
            
            print(
                "❌ Failed finishing Supabase shift:",
                error
            )
            
            return false
        }
    }
}

