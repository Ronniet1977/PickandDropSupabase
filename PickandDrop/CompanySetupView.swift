//
//  CompanySetupView.swift
//  PickandDrop
//
//  Created by Ronald Thayer Jr on 5/10/26.
//

import SwiftUI
import SwiftData

struct CompanySetupView: View {
    
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss)
    private var dismiss
    
    @State private var truckingCompany = ""
    @State private var pickupCompany = ""
    @State private var dropoffCompany = ""
    @State private var ratePerTon = ""
    
    @State private var adminUsername = "admin"
    @State private var adminPassword = ""
    
    var body: some View {
        
        NavigationStack {
            
            ZStack {
                
                LinearGradient(
                    colors: [
                        Color(red: 0.08, green: 0.11, blue: 0.18),
                        Color(red: 0.15, green: 0.22, blue: 0.35),
                        Color.black.opacity(0.95)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                Form {
                    
                    Section {
                        
                        VStack(spacing: 14) {
                            
                            Image(systemName: "truck.box.fill")
                                .font(.system(size: 52))
                                .foregroundStyle(.blue)
                            
                            Text("Pick & Drop")
                                .font(.largeTitle.bold())
                            
                            Text("Company Setup")
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    
                    Section("Company") {
                        
                        TextField(
                            "Trucking Company",
                            text: $truckingCompany
                        )
                        
                        TextField(
                            "Pickup Company",
                            text: $pickupCompany
                        )
                        
                        TextField(
                            "Dropoff Company",
                            text: $dropoffCompany
                        )
                        
                        TextField(
                            "Rate Per Ton",
                            text: $ratePerTon
                        )
                        .keyboardType(.decimalPad)
                    }
                    
                    Section("Administrator") {
                        
                        TextField(
                            "Admin Username",
                            text: $adminUsername
                        )
                        
                        SecureField(
                            "Admin Password",
                            text: $adminPassword
                        )
                    }
                    
                    Button("Create Company") {
                        guard !truckingCompany.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        ).isEmpty else {
                            return
                        }
                        
                        guard !pickupCompany.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        ).isEmpty else {
                            return
                        }
                        
                        guard !dropoffCompany.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        ).isEmpty else {
                            return
                        }
                        
                        guard adminPassword.count >= 6 else {
                            return
                        }
                        
                        let settings = CompanySettings()
                        
                        settings.truckingCompanyName =
                        truckingCompany.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        )
                        
                        settings.pickupCompanyName =
                        pickupCompany.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        )
                        
                        settings.dropoffCompanyName =
                        dropoffCompany.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        )
                        
                        settings.ratePerTon =
                        Double(ratePerTon) ?? 0
                        
                        context.insert(settings)
                        let admin = DriverProfile()
                        
                        admin.name = "Administrator"
                        admin.truckNumber = "ADMIN"
                        
                        admin.username =
                        adminUsername.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        )
                        
                        admin.password = adminPassword
                        
                        admin.role = "admin"
                        
                        admin.mustChangePassword = false
                        
                        context.insert(admin)
                        
                        do {
                            
                            try context.save()
                            
                            print("✅ Company setup complete")
                            
                            dismiss()
                            
                        } catch {
                            
                            print("❌ Failed saving company:", error)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar(.hidden, for: .navigationBar)
            }
        }
    }
}
