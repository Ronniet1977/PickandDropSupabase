import Foundation

struct SupabasePayStatement: Codable, Identifiable {
    
    let id: UUID?
    
    let statement_number: String
    
    let driver_name: String
    let truck_number: String?
    
    let week_start: String
    let week_end: String
    
    let hourly_pay: Double
    let per_load_pay: Double
    let percentage_load_pay: Double
    
    let completed_loads: Int
    let hourly_jobs: Int
    
    let gross_pay: Double
    let deductions: Double
    let net_pay: Double
    
    let ytd_earnings: Double
    
    let created_at: String?
}


final class PayStatementSupabaseManager {
    
    static let shared =
    PayStatementSupabaseManager()
    
    private init() {}
    
    
    // MARK: - Save Snapshot
    
    func saveStatement(
        _ statement: PayStatementData
    ) async -> Bool {
        
        // Never replace an existing statement.
        // Once saved, it remains historical.
        
        if await statementExists(
            statementNumber:
                statement.statementNumber
        ) {
            
            print(
                "ℹ️ Pay statement already saved:",
                statement.statementNumber
            )
            
            return true
        }
        
        
        let dateFormatter =
        DateFormatter()
        
        dateFormatter.calendar =
        Calendar(
            identifier: .gregorian
        )
        
        dateFormatter.locale =
        Locale(
            identifier: "en_US_POSIX"
        )
        
        dateFormatter.dateFormat =
        "yyyy-MM-dd"
        
        
        let body:
        [String: Any] = [
            
            "statement_number":
                statement.statementNumber,
            
            "driver_name":
                statement.driverName,
            
            "truck_number":
                statement.truckNumber,
            
            "week_start":
                dateFormatter.string(
                    from:
                        statement.weekStart
                ),
            
            "week_end":
                dateFormatter.string(
                    from:
                        statement.weekEnd
                ),
            
            "hourly_pay":
                statement.hourlyPay,
            
            "per_load_pay":
                statement.perLoadPay,
            
            "percentage_load_pay":
                statement.percentageLoadPay,
            
            "completed_loads":
                statement.completedLoads,
            
            "hourly_jobs":
                statement.hourlyJobs,
            
            "gross_pay":
                statement.grossPay,
            
            "deductions":
                statement.deductions,
            
            "net_pay":
                statement.netPay,
            
            "ytd_earnings":
                statement.ytdEarnings
        ]
        
        
        do {
            
            let data =
            try JSONSerialization.data(
                withJSONObject: body
            )
            
            _ =
            try await
            SupabaseRESTManager.shared
                .request(
                    table:
                        "pickdrop_pay_statements",
                    method: "POST",
                    body: data
                )
            
            print(
                "✅ Pay statement saved:",
                statement.statementNumber
            )
            
            return true
            
        } catch {
            
            print(
                "❌ Pay statement save failed:",
                error
            )
            
            return false
        }
    }
    
    func fetchStatement(
        statementNumber: String
    ) async -> SupabasePayStatement? {
        
        guard let encoded =
                statementNumber.addingPercentEncoding(
                    withAllowedCharacters:
                            .urlQueryAllowed
                )
        else {
            return nil
        }
        
        do {
            
            let data =
            try await
            SupabaseRESTManager.shared
                .request(
                    table:
                        "pickdrop_pay_statements",
                    query:
                        "?statement_number=eq.\(encoded)&limit=1"
                )
            
            let rows =
            try JSONDecoder()
                .decode(
                    [SupabasePayStatement].self,
                    from: data
                )
            
            return rows.first
            
        } catch {
            
            print(
                "❌ Failed to fetch pay statement:",
                error
            )
            
            return nil
        }
    }
    
    func makePayStatementData(
        from saved: SupabasePayStatement,
        companyName: String
    ) -> PayStatementData? {
        
        let formatter = DateFormatter()
        
        formatter.calendar =
        Calendar(
            identifier: .gregorian
        )
        
        formatter.locale =
        Locale(
            identifier: "en_US_POSIX"
        )
        
        formatter.dateFormat =
        "yyyy-MM-dd"
        
        guard
            let weekStart =
                formatter.date(
                    from: saved.week_start
                ),
            let weekEnd =
                formatter.date(
                    from: saved.week_end
                )
        else {
            return nil
        }
        
        return PayStatementData(
            companyName:
                companyName,
            
            driverName:
                saved.driver_name,
            
            truckNumber:
                saved.truck_number ?? "",
            
            statementNumber:
                saved.statement_number,
            
            ytdEarnings:
                saved.ytd_earnings,
            
            weekStart:
                weekStart,
            
            weekEnd:
                weekEnd,
            
            hourlyPay:
                saved.hourly_pay,
            
            perLoadPay:
                saved.per_load_pay,
            
            percentageLoadPay:
                saved.percentage_load_pay,
            
            completedLoads:
                saved.completed_loads,
            
            hourlyJobs:
                saved.hourly_jobs,
            
            grossPay:
                saved.gross_pay,
            
            deductions:
                saved.deductions
        )
    }
    
    // MARK: - Check Existing
    
    private func statementExists(
        statementNumber: String
    ) async -> Bool {
        
        guard let encoded =
                statementNumber
            .addingPercentEncoding(
                withAllowedCharacters:
                        .urlQueryAllowed
            )
        else {
            return false
        }
        
        do {
            
            let data =
            try await
            SupabaseRESTManager.shared
                .request(
                    table:
                        "pickdrop_pay_statements",
                    query:
                        "?statement_number=eq.\(encoded)&select=id"
                )
            
            let rows =
            try JSONDecoder()
                .decode(
                    [ExistingStatement].self,
                    from: data
                )
            
            return !rows.isEmpty
            
        } catch {
            
            print(
                "⚠️ Could not check pay statement:",
                error
            )
            
            return false
        }
    }
    
    
    private struct ExistingStatement:
        Decodable {
        
        let id: UUID
    }
}

