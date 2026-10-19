import Foundation

struct SupabaseExpense: Codable, Identifiable {
    
    let id: UUID
    
    let expense_date: String
    let category: String
    let vendor: String?
    let description: String?
    
    let amount: Double
    
    let truck_number: String?
    let driver_name: String?
    
    let receipt_path: String?
    let notes: String?
    
    let is_tax_deductible: Bool
    
    let created_at: String?
}

struct SupabaseExpenseCategory:
    Codable,
    Identifiable {
    
    let id: UUID
    
    let name: String
    
    let is_active: Bool
    
    let created_at: String?
}

final class ExpenseSupabaseManager {
    
    static let shared =
    ExpenseSupabaseManager()
    
    private init() {}
    
    
    // MARK: - Fetch Expenses
    func fetchCategories()
    async -> [SupabaseExpenseCategory] {
        
        do {
            
            let data =
            try await
            SupabaseRESTManager.shared
                .request(
                    table:
                        "pickdrop_expense_categories",
                    query:
                        "?select=*&is_active=eq.true&order=name.asc"
                )
            
            return try JSONDecoder()
                .decode(
                    [SupabaseExpenseCategory].self,
                    from: data
                )
            
        } catch {
            
            print(
                "❌ Failed loading expense categories:",
                error
            )
            
            return []
        }
    }
    
    func addCategory(
        name: String
    ) async -> Bool {
        
        let trimmed =
        name.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        
        guard !trimmed.isEmpty else {
            return false
        }
        
        let body:
        [String: Any] = [
            
            "name":
                trimmed,
            
            "is_active":
                true
        ]
        
        do {
            
            let bodyData =
            try JSONSerialization.data(
                withJSONObject: body
            )
            
            _ =
            try await
            SupabaseRESTManager.shared
                .request(
                    table:
                        "pickdrop_expense_categories",
                    method:
                        "POST",
                    body:
                        bodyData
                )
            
            print(
                "✅ Expense category saved:",
                trimmed
            )
            
            return true
            
        } catch {
            
            print(
                "❌ Expense category save failed:",
                error
            )
            
            return false
        }
    }
    
    func fetchExpenses() async -> [SupabaseExpense] {
        
        do {
            
            let data =
            try await
            SupabaseRESTManager.shared
                .request(
                    table:
                        "pickdrop_expenses",
                    query:
                        "?select=*&order=expense_date.desc,created_at.desc"
                )
            
            return try JSONDecoder()
                .decode(
                    [SupabaseExpense].self,
                    from: data
                )
            
        } catch {
            
            print(
                "❌ Failed loading expenses:",
                error
            )
            
            return []
        }
    }
    
    
    // MARK: - Add Expense
    
    func addExpense(
        date: Date,
        category: String,
        vendor: String,
        description: String,
        amount: Double,
        truckNumber: String,
        driverName: String,
        notes: String,
        isTaxDeductible: Bool
    ) async -> Bool {
        
        let formatter =
        DateFormatter()
        
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
        
        let body:
        [String: Any] = [
            
            "expense_date":
                formatter.string(
                    from: date
                ),
            
            "category":
                category,
            
            "vendor":
                vendor,
            
            "description":
                description,
            
            "amount":
                amount,
            
            "truck_number":
                truckNumber,
            
            "driver_name":
                driverName,
            
            "notes":
                notes,
            
            "is_tax_deductible":
                isTaxDeductible
        ]
        
        do {
            
            let bodyData =
            try JSONSerialization.data(
                withJSONObject: body
            )
            
            _ =
            try await
            SupabaseRESTManager.shared
                .request(
                    table:
                        "pickdrop_expenses",
                    method:
                        "POST",
                    body:
                        bodyData
                )
            
            print(
                "✅ Expense saved"
            )
            
            return true
            
        } catch {
            
            print(
                "❌ Expense save failed:",
                error
            )
            
            return false
        }
    }
    
    
    // MARK: - Delete Expense
    
    func deleteExpense(
        id: UUID
    ) async -> Bool {
        
        do {
            
            _ =
            try await
            SupabaseRESTManager.shared
                .request(
                    table:
                        "pickdrop_expenses",
                    method:
                        "DELETE",
                    query:
                        "?id=eq.\(id.uuidString)"
                )
            
            return true
            
        } catch {
            
            print(
                "❌ Expense delete failed:",
                error
            )
            
            return false
        }
    }
}

