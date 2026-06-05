//
//  DriverManagerView.swift
//  PickandDrop
//
//  Created by Ronald Thayer Jr on 5/8/26.
//

import SwiftUI
import SwiftData

struct DriverManagerView: View {

    @Environment(\.modelContext) private var context

    @State private var drivers: [SupabaseDriver] = []
    
    @AppStorage("currentDriverName")
    var currentDriverName = ""

    @State private var newName = ""
    @State private var newTruck = ""
    @State private var newUsername = ""

    @State private var selectedRole = "driver"
    
    @State private var companyCodeText = ""
    @State private var showJoinCode = false
    @State private var showCopied = false

    var body: some View {
        
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
            
            ScrollView {
                
                VStack(spacing: 24) {
                    
                    // CREATE DRIVER CARD
                    
                    VStack(spacing: 16) {
                        
                        Text("Create Driver")
                            .font(.title.bold())
                            .foregroundStyle(.white)
                        
                        TextField(
                            "Driver Name",
                            text: $newName
                        )
                        .textFieldStyle(.roundedBorder)
                        
                        TextField(
                            "Truck Number",
                            text: $newTruck
                        )
                        .textFieldStyle(.roundedBorder)
                        
                        TextField(
                            "Username",
                            text: $newUsername
                        )
                        .textFieldStyle(.roundedBorder)
                        
                        Picker(
                            "Role",
                            selection: $selectedRole
                        ) {
                            
                            Text("Driver")
                                .tag("driver")
                            
                            Text("Admin")
                                .tag("admin")
                        }
                        .pickerStyle(.segmented)
                        
                        Button("Create Account") {
                            
                            createDriver()
                            
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                        
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 28))
                    
                    // DRIVER LIST
                    
                    VStack(spacing: 16) {
                        
                        ForEach(drivers) { driver in
                            
                            VStack(alignment: .leading, spacing: 14) {
                                
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(driver.name)
                                            .font(.headline)
                                            .foregroundStyle(.white)
                                        
                                        Text("@\(driver.username)")
                                            .foregroundStyle(.white.opacity(0.55))
                                    }
                                    
                                    Spacer()
                                    
                                    Text(driver.role.capitalized)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(
                                            driver.role == "admin"
                                            ? .red.opacity(0.2)
                                            : .blue.opacity(0.2)
                                        )
                                        .foregroundStyle(
                                            driver.role == "admin" ? .red : .blue
                                        )
                                        .clipShape(Capsule())
                                }
                                
                                HStack(spacing: 12) {
                                    Button {
                                        Task {
                                            await DriverSupabaseManager.shared
                                                .resetPassword(id: driver.id)

                                            loadDrivers()
                                        }
                                    } label: {
                                        Label("Reset", systemImage: "key.fill")
                                    }
                                    .tint(.orange)
                                    
                                    Button {

                                        Task {

                                            await DriverSupabaseManager.shared
                                                .setDriverActive(
                                                    id: driver.id,
                                                    isActive: !driver.is_active
                                                )

                                            loadDrivers()
                                        }

                                    } label: {

                                        Label(
                                            driver.is_active ? "Disable" : "Enable",
                                            systemImage:
                                                driver.is_active
                                                ? "pause.circle.fill"
                                                : "play.circle.fill"
                                        )
                                    }
                                    .tint(.blue)
                                    
                                    Button(role: .destructive) {
                                        Task {
                                            await DriverSupabaseManager.shared
                                                .deleteDriver(id: driver.id)

                                            loadDrivers()
                                        }
                                    } label: {
                                        Label("Delete", systemImage: "trash.fill")
                                    }
                                    .disabled(driver.name == currentDriverName)
                                    .tint(.red)
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.regular)
                            }
                            .padding()
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Driver Manager")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {

                        regenerateCompanyCode()

                    } label: {

                        Label(
                            "Generate New Code",
                            systemImage: "arrow.clockwise.circle.fill"
                        )
                    }
                    
                    Button {
                        Task {
                            let settings =
                                await CompanySupabaseManager
                                    .shared
                                    .fetchCompanySettings()

                            companyCodeText =
                                settings?.company_join_code
                                ?? "No code found"

                            showJoinCode = true
                        }

                    } label: {
                        Label(
                            "View Company Code",
                            systemImage: "number.circle.fill"
                        )
                    }
                    
                    Button {
                        //DriverSyncManager.exportDrivers(
                            //drivers: drivers
                        //)
                    } label: {
                        Label(
                            "Sync Drivers",
                            systemImage: "arrow.triangle.2.circlepath"
                        )
                    }
                } label: {
                    Image(systemName: "ellipsis.circle.fill")
                        .font(.title3)
                }
            }
        }
        .onAppear {
            loadDrivers()
        }
        .alert(
            "Company Join Code",
            isPresented: $showJoinCode
        ) {

            Button("Copy Code") {
                UIPasteboard.general.string = companyCodeText
            }

            Button("OK", role: .cancel) { }

        } message: {

            Text(companyCodeText)
        }
    }
    
    func loadDrivers() {

        Task {

            let loaded =
                await DriverSupabaseManager
                    .shared
                    .fetchDrivers()

            await MainActor.run {
                drivers = loaded
            }
        }
    }
    
    func regenerateCompanyCode() {
        print("Supabase version coming next")
    }
    
    func createDriver() {

        Task {

            await DriverSupabaseManager.shared.addDriver(
                name: newName,
                username: newUsername.lowercased(),
                password: "1234",
                truckNumber: newTruck,
                role: selectedRole
            )

            await MainActor.run {

                newName = ""
                newTruck = ""
                newUsername = ""
                selectedRole = "driver"
            }
        }
    }
    
    func deleteDriver(_ driver: DriverProfile) {

        context.delete(driver)

        do {

            try context.save()
            
            if drivers.contains(where: {
                $0.name == currentDriverName &&
                $0.role == "admin"
            }) {

                //DriverSyncManager.exportDrivers(
                    //drivers: drivers
                //)
            }

            print("✅ Driver deleted")

        } catch {

            print("❌ Failed deleting driver:", error)
        }
    }
}
