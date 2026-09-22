import Foundation

struct SupabaseShift: Codable, Identifiable {
    
    let id: UUID
    
    let driver_name: String
    let username: String
    let truck_number: String
    
    let pickup_location: String?
    let dropoff_location: String?
    
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
        truckNumber: String,
        pickupLocation: String,
        dropoffLocation: String
    ) async -> SupabaseShift? {
        
        let now =
        ISO8601DateFormatter()
            .string(from: Date())
        
        let body: [String: Any] = [
            "driver_name": driverName,
            "username": username.lowercased(),
            "truck_number": truckNumber,
            "pickup_location": pickupLocation,
            "dropoff_location": dropoffLocation,
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
    
    func fetchActiveShift(
        driverName: String
    ) async -> SupabaseShift? {
        
        do {
            
            let encodedName =
            driverName.addingPercentEncoding(
                withAllowedCharacters: .urlQueryAllowed
            ) ?? driverName
            
            let data =
            try await SupabaseRESTManager.shared.request(
                table: "pickdrop_shifts",
                query:
                    "?select=*&driver_name=eq.\(encodedName)&status=eq.active&order=started_at.desc&limit=1"
            )
            
            let shifts =
            try JSONDecoder().decode(
                [SupabaseShift].self,
                from: data
            )
            
            return shifts.first
            
        } catch {
            
            print(
                "❌ Failed loading active shift:",
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
    
    func finishShift(
        id: UUID
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
                query: "?id=eq.\(id.uuidString)",
                body: bodyData
            )

            print(
                "✅ Specific Supabase shift finished:",
                id
            )

            return true

        } catch {

            print(
                "❌ Failed finishing specific Supabase shift:",
                error
            )

            return false
        }
    }
}

struct SupabaseLocation: Codable, Identifiable {
    
    let id: UUID
    let name: String
    let location_type: String
    let is_active: Bool
    
    let billing_type: String?
    
    let rate_per_ton: Double?
    let fuel_surcharge_per_ton: Double?
    let rate_per_load: Double?
    let rate_per_hour: Double?
    
    let created_at: String?
}

final class LocationSupabaseManager {
    
    static let shared = LocationSupabaseManager()
    
    private init() {}
    
    func addLocation(
        name: String,
        locationType: String,
        billingType: String,
        ratePerTon: Double?,
        fuelSurchargePerTon: Double?,
        ratePerLoad: Double?,
        ratePerHour: Double?
    ) async -> Bool {
        
        let cleanName =
        name.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        
        guard !cleanName.isEmpty else {
            return false
        }
        
        var body: [String: Any] = [
            "name": cleanName,
            "location_type": locationType,
            "billing_type": billingType,
            "is_active": true
        ]
        
        if let ratePerTon {
            body["rate_per_ton"] = ratePerTon
        }
        
        if let fuelSurchargePerTon {
            body["fuel_surcharge_per_ton"] = fuelSurchargePerTon
        }
        
        if let ratePerLoad {
            body["rate_per_load"] = ratePerLoad
        }
        
        if let ratePerHour {
            body["rate_per_hour"] = ratePerHour
        }
        
        do {
            
            let data =
            try JSONSerialization.data(
                withJSONObject: body
            )
            
            _ = try await SupabaseRESTManager.shared
                .request(
                    table: "pickdrop_locations",
                    method: "POST",
                    body: data
                )
            
            print(
                "✅ Location added:",
                cleanName,
                locationType
            )
            
            return true
            
        } catch {
            
            print(
                "❌ Failed adding location:",
                error
            )
            
            return false
        }
    }
    
    func updateLocationRates(
        id: UUID,
        billingType: String,
        ratePerTon: Double,
        fuelSurchargePerTon: Double,
        ratePerLoad: Double,
        ratePerHour: Double
    ) async -> Bool {
        
        let body: [String: Any] = [
            "billing_type": billingType,
            "rate_per_ton": ratePerTon,
            "fuel_surcharge_per_ton": fuelSurchargePerTon,
            "rate_per_load": ratePerLoad,
            "rate_per_hour": ratePerHour
        ]
        
        do {
            
            let data =
            try JSONSerialization.data(
                withJSONObject: body
            )
            
            _ = try await
            SupabaseRESTManager.shared.request(
                table: "pickdrop_locations",
                method: "PATCH",
                query: "?id=eq.\(id.uuidString)",
                body: data
            )
            
            print(
                "✅ Location rates updated:",
                billingType
            )
            
            return true
            
        } catch {
            
            print(
                "❌ Failed updating location rates:",
                error
            )
            
            return false
        }
    }
    
    func deleteLocation(
        id: UUID
    ) async -> Bool {
        
        do {
            
            let response = try await
            SupabaseRESTManager.shared
                .request(
                    table: "pickdrop_locations",
                    method: "DELETE",
                    query:
                        "?id=eq.\(id.uuidString)&select=*"
                )
            
            print("🗑️ DELETE RESPONSE:")
            print(String(data: response, encoding: .utf8) ?? "No response body")
            
            return true
            
        } catch {
            
            print(
                "❌ Failed deleting location:",
                error
            )
            
            return false
        }
    }
    
    func fetchLocations() async -> [SupabaseLocation] {
        
        do {
            
            let data =
            try await SupabaseRESTManager.shared.request(
                table: "pickdrop_locations",
                query: "?select=*&order=name"
            )
            
            let locations =
            try JSONDecoder().decode(
                [SupabaseLocation].self,
                from: data
            )
            
            print(
                "📍 LOCATIONS:",
                locations.map {
                    "\($0.name) - \($0.location_type) - \($0.is_active)"
                }
            )
            
            return locations
            
        } catch {
            
            print(
                "❌ Failed loading locations:",
                error
            )
            
            return []
        }
    }
}
