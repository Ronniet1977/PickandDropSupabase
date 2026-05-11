//
//  CompanySetupView.swift
//  PickandDrop
//
//  Created by Ronald Thayer Jr on 5/10/26.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct CompanySetupView: View {
    
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss)
    private var dismiss
    
    @Query(sort: \DriverProfile.name)
    var drivers: [DriverProfile]
    
    @State private var truckingCompany = ""
    @State private var pickupCompany = ""
    @State private var dropoffCompany = ""
    @State private var ratePerTon = ""
    
    @State private var adminUsername = "admin"
    @State private var adminPassword = ""
    
    @State private var starterDriverName = ""
    @State private var starterDriverTruck = ""
    @State private var starterDriverUsername = ""
    
    @State private var showFolderPicker = false
    @State private var selectedFolderName = ""
    @State private var errorText = ""
    @State private var joinExistingCompany = false
    @State private var joinCode = ""
    
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
                            
                            Text(
                                joinExistingCompany
                                ? "Join Company"
                                : "Company Setup"
                            )
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    
                    Section("Setup Type") {
                        
                        Toggle(
                            "Join Existing Company",
                            isOn: $joinExistingCompany
                        )
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
                    
                    if !joinExistingCompany {
                        
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
                        
                        if !joinExistingCompany {

                            Section("Starter Driver") {

                                TextField(
                                    "Driver Name",
                                    text: $starterDriverName
                                )

                                TextField(
                                    "Truck Number",
                                    text: $starterDriverTruck
                                )

                                TextField(
                                    "Username",
                                    text: $starterDriverUsername
                                )

                                Text(
                                    "Default password: 1234"
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                    if joinExistingCompany {

                        Section("Company Join Code") {

                            TextField(
                                "Enter Company Code",
                                text: $joinCode
                            )
                            .textInputAutocapitalization(.characters)
                        }
                    }
                    
                    Section("Shared Reports Folder") {
                        
                        Button {
                            
                            showFolderPicker = true
                            
                        } label: {
                            
                            Label(
                                selectedFolderName.isEmpty
                                ? "Select Shared Folder"
                                : selectedFolderName,
                                systemImage: "folder.fill"
                            )
                        }
                        
                        if !selectedFolderName.isEmpty {
                            
                            Text("Shared folder connected")
                                .foregroundStyle(.green)
                                .font(.caption)
                        }
                    }
                    
                    if !errorText.isEmpty {
                        
                        Text(errorText)
                            .foregroundStyle(.red)
                    }
                    
                    Button(
                        joinExistingCompany
                        ? "Join Company"
                        : "Create Company"
                    ) {
                        
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
                        
                        guard !selectedFolderName.isEmpty else {
                            
                            errorText = "Please select a shared folder"
                            
                            return
                        }
                        
                        if joinExistingCompany {
                            
                            let existingCode = "PickandDrop"
                            
                            guard
                                joinCode
                                    .trimmingCharacters(
                                        in: .whitespacesAndNewlines
                                    )
                                    .uppercased()
                                    ==
                                    existingCode.uppercased()
                            else {
                                
                                errorText = "Invalid company code"
                                
                                return
                            }
                            
                        } else {
                            
                            guard adminPassword.count >= 6 else {
                                
                                errorText =
                                "Admin password must be at least 6 characters"
                                
                                return
                            }
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
                        
                        if !joinExistingCompany {
                            
                            let generatedCode =
                            truckingCompany
                                .uppercased()
                                .replacingOccurrences(of: " ", with: "")
                            + "-\(Int.random(in: 1000...9999))"
                            
                            settings.companyJoinCode = generatedCode
                            
                            UserDefaults.standard.set(
                                generatedCode,
                                forKey: "SharedCompanyCode"
                            )
                            
                            print("✅ Company Join Code:",
                                  generatedCode)
                        }
                        
                        context.insert(settings)
                        
                        if !joinExistingCompany {
                            
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
                            
                            UserDefaults.standard.set(
                                admin.name,
                                forKey: "currentDriverName"
                            )
                            
                            UserDefaults.standard.set(
                                true,
                                forKey: "isLoggedIn"
                            )
                        }
                        
                        if !joinExistingCompany &&
                           !starterDriverName.isEmpty {

                            let starterDriver = DriverProfile()

                            starterDriver.name =
                                starterDriverName

                            starterDriver.truckNumber =
                                starterDriverTruck

                            starterDriver.username =
                                starterDriverUsername
                                    .lowercased()

                            starterDriver.password = "1234"

                            starterDriver.role = "driver"

                            starterDriver.mustChangePassword = true

                            context.insert(starterDriver)
                        }
                        
                        do {
                            
                            try context.save()
                            
                            DriverSyncManager.exportDrivers(
                                drivers: drivers
                            )
                            
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
                .fileImporter(
                    isPresented: $showFolderPicker,
                    allowedContentTypes: [.folder]
                ) { result in

                    switch result {

                    case .success(let url):

                        let didAccess =
                            url.startAccessingSecurityScopedResource()

                        if didAccess {

                            StorageManager.saveTruckReportsFolder(url)

                            selectedFolderName =
                                url.lastPathComponent

                            print("✅ Shared folder selected:",
                                  url.path)

                            url.stopAccessingSecurityScopedResource()
                        }

                    case .failure(let error):

                        print("❌ Folder picker failed:", error)
                    }
                }
            }
        }
    }
}
