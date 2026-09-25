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
    
    // MARK: - Hourly Job Tracking
    
    let hourly_started_at: String?
    let hourly_ended_at: String?
    let hourly_rate: Double?
    let hourly_billable_hours: Double?
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
    
    // MARK: - Start Hourly Job
    
    func startHourlyJobIfNeeded(
        shift: SupabaseShift,
        hourlyRate: Double
    ) async -> Bool {
        
        // Already started — never reset the first-ticket time.
        if shift.hourly_started_at != nil {
            print("⏱️ Hourly job already started")
            return true
        }
        
        let now =
        ISO8601DateFormatter()
            .string(from: Date())
        
        let body: [String: Any] = [
            "hourly_started_at": now,
            "hourly_rate": hourlyRate
        ]
        
        do {
            
            let bodyData =
            try JSONSerialization.data(
                withJSONObject: body
            )
            
            _ = try await
            SupabaseRESTManager.shared.request(
                table: "pickdrop_shifts",
                method: "PATCH",
                query:
                    "?id=eq.\(shift.id.uuidString)&hourly_started_at=is.null",
                body: bodyData
            )
            
            print(
                "⏱️ Hourly job started:",
                shift.driver_name,
                "Rate:",
                hourlyRate
            )
            
            return true
            
        } catch {
            
            print(
                "❌ Failed starting hourly job:",
                error
            )
            
            return false
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
        
        let finishDate = Date()
        
        let formatter =
        ISO8601DateFormatter()
        
        let now =
        formatter.string(from: finishDate)
        
        // Fetch the shift first so we can determine
        // whether an hourly job was started.
        
        let shifts = await fetchShifts()
        
        guard let shift =
                shifts.first(where: { $0.id == id })
        else {
            print("❌ Shift not found:", id)
            return false
        }
        
        var body: [String: Any] = [
            "ended_at": now,
            "status": "finished"
        ]
        
        // MARK: - Finish Hourly Job
        
        if let hourlyStartedString =
            shift.hourly_started_at,
           
            let hourlyStartedDate =
            formatter.date(
                from: hourlyStartedString
            ) {
            
            let elapsedSeconds =
            finishDate.timeIntervalSince(
                hourlyStartedDate
            )
            
            let actualHours =
            max(0, elapsedSeconds / 3600)
            
            // Round to nearest 30 minutes.
            // Examples:
            // 8:14 -> 8.0
            // 8:15 -> 8.5
            // 8:44 -> 8.5
            // 8:45 -> 9.0
            
            let billableHours =
            (actualHours * 2).rounded() / 2
            
            body["hourly_ended_at"] = now
            body["hourly_billable_hours"] =
            billableHours
            
            print(
                "⏱️ Hourly job finished",
                "Actual:",
                actualHours,
                "Billable:",
                billableHours
            )
        }
        
        do {
            
            let bodyData =
            try JSONSerialization.data(
                withJSONObject: body
            )
            
            _ = try await
            SupabaseRESTManager.shared.request(
                table: "pickdrop_shifts",
                method: "PATCH",
                query:
                    "?id=eq.\(id.uuidString)",
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
    
    func updateHourlyTimes(
        id: UUID,
        startDate: Date,
        endDate: Date
    ) async -> Bool {
        
        guard endDate >= startDate else {
            print("❌ Hourly end time is before start time")
            return false
        }
        
        let formatter =
        ISO8601DateFormatter()
        
        let startString =
        formatter.string(from: startDate)
        
        let endString =
        formatter.string(from: endDate)
        
        let actualHours =
        endDate.timeIntervalSince(startDate) / 3600
        
        // Nearest 30 minutes.
        // 8:14 -> 8.0
        // 8:15 -> 8.5
        // 8:44 -> 8.5
        // 8:45 -> 9.0
        
        let billableHours =
        (actualHours * 2).rounded() / 2
        
        let body: [String: Any] = [
            "hourly_started_at": startString,
            "hourly_ended_at": endString,
            "hourly_billable_hours": billableHours
        ]
        
        do {
            
            let bodyData =
            try JSONSerialization.data(
                withJSONObject: body
            )
            
            _ = try await
            SupabaseRESTManager.shared.request(
                table: "pickdrop_shifts",
                method: "PATCH",
                query:
                    "?id=eq.\(id.uuidString)",
                body: bodyData
            )
            
            print(
                "✅ Hourly times updated",
                "Start:",
                startString,
                "End:",
                endString,
                "Billable:",
                billableHours
            )
            
            return true
            
        } catch {
            
            print(
                "❌ Failed updating hourly times:",
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
