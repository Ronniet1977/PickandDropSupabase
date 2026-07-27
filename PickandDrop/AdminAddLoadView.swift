import SwiftUI

struct AdminAddLoadView: View {
    
    let driverName: String
    let truckNumber: String
    let settings: SupabaseCompanySettings?
    
    var onSaved: (() -> Void)? = nil
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var pickupTicket = ""
    @State private var pickupTons = ""
    @State private var isSaving = false
    
    var body: some View {
        Form {
            
            Section(driverName) {
                Text("Truck \(truckNumber)")
                    .foregroundStyle(.secondary)
            }
            
            Section(settings?.pickup_company_name ?? "Pickup") {
                
                TextField(
                    "Ticket Number (Optional)",
                    text: $pickupTicket
                )
                
                TextField(
                    "Tons",
                    text: $pickupTons
                )
                .keyboardType(.decimalPad)
            }
            
            Button {
                Task {
                    await addLoad()
                }
            } label: {
                Label(
                    isSaving ? "Adding Load..." : "Add Load",
                    systemImage: "plus.circle.fill"
                )
            }
            .disabled(!isValidLoad || isSaving)
        }
        .navigationTitle("Add Load")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
    }
    
    private var isValidLoad: Bool {
        (Double(pickupTons) ?? 0) > 0
    }
    
    private func addLoad() async {
        guard !isSaving else {
            return
        }
        
        guard let tons = Double(pickupTons), tons > 0 else {
            return
        }
        
        await MainActor.run {
            isSaving = true
        }
        
        await LoadSupabaseManager.shared.addLoad(
            driverName: driverName,
            truckNumber: truckNumber,
            pickupTicketNumber: pickupTicket.trimmingCharacters(
                in: .whitespacesAndNewlines
            ),
            pickupTons: tons
        )
        
        await MainActor.run {
            onSaved?()
            dismiss()
        }
    }
}
