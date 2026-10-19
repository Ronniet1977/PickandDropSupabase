import SwiftUI

struct ExpensesView: View {
    
    @State private var expenses: [SupabaseExpense] = []
    
    @State private var showAddExpense = false
    
    private var totalExpenses: Double {
        expenses.reduce(0.0) {
            $0 + $1.amount
        }
    }
    
    var body: some View {
        
        List {
            
            Section {
                
                HStack {
                    
                    Text("Total Expenses")
                    
                    Spacer()
                    
                    Text(
                        totalExpenses,
                        format:
                                .currency(
                                    code: "USD"
                                )
                    )
                    .font(.headline)
                }
                
            }
            
            Section("Expenses") {
                
                if expenses.isEmpty {
                    
                    Text("No expenses yet")
                        .foregroundStyle(.secondary)
                    
                } else {
                    
                    ForEach(expenses) { expense in
                        
                        VStack(
                            alignment: .leading,
                            spacing: 6
                        ) {
                            
                            HStack {
                                
                                Text(expense.category)
                                    .font(.headline)
                                
                                Spacer()
                                
                                Text(
                                    expense.amount,
                                    format:
                                            .currency(
                                                code: "USD"
                                            )
                                )
                                .font(.headline)
                            }
                            
                            if let vendor = expense.vendor,
                               !vendor.isEmpty {
                                
                                Text(vendor)
                                    .foregroundStyle(.secondary)
                            }
                            
                            if let description =
                                expense.description,
                               !description.isEmpty {
                                
                                Text(description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            HStack {
                                
                                Text(expense.expense_date)
                                    .font(.caption)
                                
                                Spacer()
                                
                                if expense.is_tax_deductible {
                                    
                                    Label(
                                        "Deductible",
                                        systemImage:
                                            "checkmark.circle.fill"
                                    )
                                    .font(.caption)
                                    .foregroundStyle(.green)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete(
                        perform: deleteExpenses
                    )
                }
            }
        }
        .navigationTitle("Expenses")
        .toolbar {
            
            ToolbarItem(
                placement:
                        .topBarTrailing
            ) {
                
                Button {
                    
                    showAddExpense = true
                    
                } label: {
                    
                    Image(
                        systemName:
                            "plus"
                    )
                }
            }
        }
        .sheet(
            isPresented:
                $showAddExpense
        ) {
            
            AddExpenseView {
                
                Task {
                    await loadExpenses()
                }
            }
        }
        .task {
            
            await loadExpenses()
        }
    }
    
    
    private func loadExpenses() async {
        
        let loaded =
        await ExpenseSupabaseManager
            .shared
            .fetchExpenses()
        
        await MainActor.run {
            
            expenses = loaded
        }
    }
    
    
    private func deleteExpenses(
        at offsets: IndexSet
    ) {
        
        let deleting =
        offsets.map {
            expenses[$0]
        }
        
        expenses.remove(
            atOffsets: offsets
        )
        
        Task {
            
            for expense in deleting {
                
                _ =
                await ExpenseSupabaseManager
                    .shared
                    .deleteExpense(
                        id: expense.id
                    )
            }
            
            await loadExpenses()
        }
    }
}

struct AddExpenseView: View {
    
    let onSaved: () -> Void
    
    @Environment(\.dismiss)
    private var dismiss
    
    @State private var expenseDate =
    Date()
    
    @State private var category = ""
    
    @State private var vendor = ""
    
    @State private var expenseDescription = ""
    
    @State private var amount = ""
    
    @State private var truckNumber = ""
    
    @State private var driverName = ""
    
    @State private var notes = ""
    
    @State private var isTaxDeductible =
    true
    
    @State private var isSaving =
    false
    @State private var showAddCategory = false
    @State private var newCategory = ""
    
    @State private var categories:
    [SupabaseExpenseCategory] = []
    
    
    var body: some View {
        
        NavigationStack {
            
            Form {
                
                Section("Expense") {
                    
                    DatePicker(
                        "Date",
                        selection:
                            $expenseDate,
                        displayedComponents:
                                .date
                    )
                    
                    Picker(
                        "Category",
                        selection:
                            $category
                    ) {
                        Text("Add Category…")
                            .tag("__add_category__")
                        
                        ForEach(
                            categories
                        ) { item in
                            
                            Text(item.name)
                                .tag(item.name)
                        }
                    }
                    .onChange(
                        of: category
                    ) { _, newValue in
                        
                        if newValue ==
                            "__add_category__" {
                            
                            showAddCategory = true
                            category = ""
                        }
                    }
                    
                    TextField(
                        "Vendor",
                        text:
                            $vendor
                    )
                    
                    TextField(
                        "Description",
                        text:
                            $expenseDescription
                    )
                    
                    TextField(
                        "Amount",
                        text:
                            $amount
                    )
                    .keyboardType(
                        .decimalPad
                    )
                }
                
                
                Section("Truck / Driver") {
                    
                    TextField(
                        "Truck Number",
                        text:
                            $truckNumber
                    )
                    
                    TextField(
                        "Driver",
                        text:
                            $driverName
                    )
                }
                
                
                Section("Tax") {
                    
                    Toggle(
                        "Tax Deductible",
                        isOn:
                            $isTaxDeductible
                    )
                }
                
                
                Section("Notes") {
                    
                    TextField(
                        "Notes",
                        text:
                            $notes,
                        axis:
                                .vertical
                    )
                }
            }
            .navigationTitle(
                "Add Expense"
            )
            .navigationBarTitleDisplayMode(
                .inline
            )
            .task {
                
                let loaded =
                await ExpenseSupabaseManager
                    .shared
                    .fetchCategories()
                
                await MainActor.run {
                    
                    categories = loaded
                    
                    if category.isEmpty {
                        category =
                        loaded.first?.name
                        ?? ""
                    }
                }
            }
            .toolbar {
                
                ToolbarItem(
                    placement:
                            .cancellationAction
                ) {
                    
                    Button("Cancel") {
                        
                        dismiss()
                    }
                }
                
                ToolbarItem(
                    placement:
                            .confirmationAction
                ) {
                    
                    Button("Save") {
                        
                        Task {
                            
                            await saveExpense()
                        }
                    }
                    .disabled(
                        isSaving ||
                        Double(amount) == nil
                    )
                }
            }
            .alert(
                "Add Expense Category",
                isPresented:
                    $showAddCategory
            ) {
                
                TextField(
                    "Category Name",
                    text:
                        $newCategory
                )
                
                Button(
                    "Cancel",
                    role: .cancel
                ) {
                    
                    newCategory = ""
                }
                
                Button("Add") {
                    
                    let trimmed =
                    newCategory
                        .trimmingCharacters(
                            in:
                                    .whitespacesAndNewlines
                        )
                    
                    guard !trimmed.isEmpty else {
                        return
                    }
                    
                    Task {
                        
                        let saved =
                        await ExpenseSupabaseManager
                            .shared
                            .addCategory(
                                name: trimmed
                            )
                        
                        if saved {
                            
                            let loaded =
                            await ExpenseSupabaseManager
                                .shared
                                .fetchCategories()
                            
                            await MainActor.run {
                                
                                categories =
                                loaded
                                
                                category =
                                trimmed
                                
                                newCategory =
                                ""
                            }
                        }
                    }
                }
                
            } message: {
                
                Text(
                    "This category will be available for future expenses."
                )
            }
        }
    }
    
    
    private func saveExpense() async {
        
        guard let value =
                Double(amount)
        else {
            return
        }
        
        isSaving = true
        
        let saved =
        await ExpenseSupabaseManager
            .shared
            .addExpense(
                date:
                    expenseDate,
                category:
                    category,
                vendor:
                    vendor,
                description:
                    expenseDescription,
                amount:
                    value,
                truckNumber:
                    truckNumber,
                driverName:
                    driverName,
                notes:
                    notes,
                isTaxDeductible:
                    isTaxDeductible
            )
        
        await MainActor.run {
            
            isSaving = false
            
            if saved {
                
                onSaved()
                dismiss()
            }
        }
    }
}

