import Foundation

final class LegacyShiftMigrationManager {
    
    static let shared =
    LegacyShiftMigrationManager()
    
    private init() {}
    
    func migrate(
        shifts: [Shift],
        drivers: [DriverProfile]
    ) async -> Bool {
        
        let finishedLocalShifts =
        shifts.filter {
            $0.status == "finished" &&
            $0.endedAt != nil
        }
        
        guard !finishedLocalShifts.isEmpty else {
            
            print(
                "ℹ️ No legacy shifts to migrate"
            )
            
            return true
        }
        
        // Fetch whatever this authenticated
        // user is allowed to see from Supabase.
        let cloudShifts =
        await ShiftSupabaseManager.shared
            .fetchShifts()
        
        let existingIDs =
        Set(
            cloudShifts.map {
                $0.id
            }
        )
        
        let shiftsToUpload =
        finishedLocalShifts.filter {
            !existingIDs.contains($0.id)
        }
        
        guard !shiftsToUpload.isEmpty else {
            
            print(
                "✅ Legacy shifts already migrated"
            )
            
            return true
        }
        
        print(
            "📦 Legacy shifts to migrate:",
            shiftsToUpload.count
        )
        
        var failedCount = 0
        
        for shift in shiftsToUpload {
            
            guard let driver =
                    drivers.first(where: {
                        $0.name == shift.driverName
                    })
            else {
                
                print(
                    "⚠️ No driver profile for:",
                    shift.driverName
                )
                
                failedCount += 1
                continue
            }
            
            let success =
            await ShiftSupabaseManager.shared
                .uploadLegacyShift(
                    shift,
                    username:
                        driver.username,
                    truckNumber:
                        driver.truckNumber
                )
            
            if !success {
                failedCount += 1
            }
        }
        
        if failedCount == 0 {
            
            print(
                "✅ Legacy shift migration complete"
            )
            
            return true
            
        } else {
            
            print(
                "⚠️ Legacy migration finished with \(failedCount) failure(s)"
            )
            
            return false
        }
    }
}

