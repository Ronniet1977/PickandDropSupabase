import SwiftUI

struct EditSupabaseLoadView: View {
    
    let load: SupabaseLoad
    let settings: SupabaseCompanySettings?
    let canDelete: Bool
    var onSaved: (() -> Void)? = nil
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var pickupTicket = ""
    @State private var pickupTons = ""
    @State private var deliveryTicket = ""
    @State private var deliveryTons = ""
    @State private var status = "pickedUp"
    @State private var showDeleteAlert = false
    @State private var showSavedAlert = false
    
    var body: some View {
        Form {
            
            Section(settings?.pickup_company_name ?? "Pickup") {
                
                TextField("Ticket Number", text: $pickupTicket)
                
                TextField("Tons", text: $pickupTons)
                    .keyboardType(.decimalPad)
            }
            
            Section(settings?.dropoff_company_name ?? "Dropoff") {
                
                TextField("Ticket Number", text: $deliveryTicket)
                
                TextField("Tons", text: $deliveryTons)
                    .keyboardType(.decimalPad)
            }
            
            Section("Status") {
                
                Picker("Status", selection: $status) {
                    Text("Picked Up").tag("pickedUp")
                    Text("Delivered").tag("delivered")
                }
                .pickerStyle(.segmented)
            }
            
            Button {
                Task {
                    await save()
                }
            } label: {
                Label("Save Changes", systemImage: "checkmark.circle.fill")
            }
            
            if canDelete {
                
                Button(role: .destructive) {
                    showDeleteAlert = true
                } label: {
                    Label("Delete Load", systemImage: "trash.fill")
                }
            }
        }
        .navigationTitle("Edit Load")
        .onAppear {
            pickupTicket = load.pickup_ticket_number ?? ""
            pickupTons = String(format: "%.2f", load.pickup_tons ?? 0)
            
            deliveryTicket = load.delivery_ticket_number ?? ""
            deliveryTons = String(format: "%.2f", load.delivery_tons ?? 0)
            
            status = load.status ?? "pickedUp"
        }
        .alert("Load Updated", isPresented: $showSavedAlert) {
            Button("OK") {
                dismiss()
            }
        }
        
        .alert("Delete Load?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            
            Button("Delete", role: .destructive) {
                Task {
                    await deleteLoad()
                }
            }
        } message: {
            Text("This will permanently delete this load from Supabase.")
        }
    }
    
    func save() async {
        
        await LoadSupabaseManager.shared.updateLoad(
            id: load.id,
            pickupTicketNumber: pickupTicket,
            pickupTons: Double(pickupTons) ?? 0,
            deliveryTicketNumber: deliveryTicket,
            deliveryTons: Double(deliveryTons) ?? 0,
            status: status
        )
        
        await MainActor.run {
            onSaved?()
            showSavedAlert = true
        }
    }
    
    func deleteLoad() async {
        
        await LoadSupabaseManager.shared.deleteLoad(
            id: load.id
        )
        
        await MainActor.run {
            onSaved?()
            dismiss()
        }
    }
}
