import SwiftUI

struct EditCompanyInfoView: View {
    
    let settings: SupabaseCompanySettings
    var onSaved: (() -> Void)? = nil
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var truckingCompanyName = ""
    @State private var pickupCompanyName = ""
    @State private var dropoffCompanyName = ""
    @State private var companyJoinCode = ""
    @State private var ratePerTon = ""
    
    @State private var isSaving = false
    
    var body: some View {
        Form {
            
            Section("Company") {
                TextField(
                    "Trucking Company Name",
                    text: $truckingCompanyName
                )
            }
            
            Section("Route") {
                TextField(
                    "Pickup Company",
                    text: $pickupCompanyName
                )
                
                TextField(
                    "Dropoff Company",
                    text: $dropoffCompanyName
                )
            }
            
            Section("Company Access") {
                TextField(
                    "Join Company Code",
                    text: $companyJoinCode
                )
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
            }
            
            Section("Billing") {
                TextField(
                    "Rate Per Ton",
                    text: $ratePerTon
                )
                .keyboardType(.decimalPad)
            }
            
            Button {
                Task {
                    await saveSettings()
                }
            } label: {
                Label(
                    isSaving ? "Saving..." : "Save Changes",
                    systemImage: "checkmark.circle.fill"
                )
            }
            .disabled(!isValid || isSaving)
        }
        .navigationTitle("Edit Company Info")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
        .onAppear {
            truckingCompanyName =
            settings.trucking_company_name
            
            pickupCompanyName =
            settings.pickup_company_name
            
            dropoffCompanyName =
            settings.dropoff_company_name
            
            companyJoinCode =
            settings.company_join_code
            
            ratePerTon =
            String(
                format: "%.2f",
                settings.rate_per_ton
            )
        }
    }
    
    private var isValid: Bool {
        !truckingCompanyName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty &&
        !pickupCompanyName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty &&
        !dropoffCompanyName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty &&
        (Double(ratePerTon) ?? -1) >= 0
    }
    
    private func saveSettings() async {
        
        guard !isSaving else {
            return
        }
        
        guard let rate = Double(ratePerTon) else {
            return
        }
        
        await MainActor.run {
            isSaving = true
        }
        
        await CompanySupabaseManager.shared.updateCompanySettings(
            id: settings.id,
            truckingCompanyName:
                truckingCompanyName.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ),
            pickupCompanyName:
                pickupCompanyName.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ),
            dropoffCompanyName:
                dropoffCompanyName.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ),
            companyJoinCode:
                companyJoinCode.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ),
            ratePerTon: rate
        )
        
        await MainActor.run {
            onSaved?()
            dismiss()
        }
    }
}

