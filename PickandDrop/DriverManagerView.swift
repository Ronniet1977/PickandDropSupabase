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
    
    @State private var resetDriver: SupabaseDriver?
    @State private var temporaryPassword = ""
    @State private var showResetResult = false
    @State private var resetMessage = ""
    @State private var isResettingPassword = false
    @State private var isCreatingDriver = false
    
    @State private var driverToDelete: SupabaseDriver?
    @State private var showDeleteConfirmation = false

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
                        
                        Button {
                            Task {
                                await createDriver()
                            }
                        } label: {
                            if isCreatingDriver {
                                ProgressView()
                            } else {
                                Label(
                                    "Create Account",
                                    systemImage: "person.badge.plus"
                                )
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                        .disabled(
                            newName.trimmingCharacters(
                                in: .whitespacesAndNewlines
                            ).isEmpty ||
                            newUsername.trimmingCharacters(
                                in: .whitespacesAndNewlines
                            ).isEmpty ||
                            newTruck.trimmingCharacters(
                                in: .whitespacesAndNewlines
                            ).isEmpty ||
                            isCreatingDriver
                        )
                        
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
                                            await resetDriverPassword(driver)
                                        }
                                    } label: {
                                        Label(
                                            isResettingPassword &&
                                            resetDriver?.id == driver.id
                                            ? "Resetting..."
                                            : "Reset",
                                            systemImage: "key.fill"
                                        )
                                    }
                                    .tint(.orange)
                                    .disabled(isResettingPassword)
                                    
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

                                        driverToDelete = driver
                                        showDeleteConfirmation = true

                                    } label: {

                                        Label(
                                            "Delete",
                                            systemImage: "trash.fill"
                                        )
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
            "Delete Driver?",
            isPresented: $showDeleteConfirmation,
            presenting: driverToDelete
        ) { driver in

            Button(
                "Delete",
                role: .destructive
            ) {

                Task {

                    do {

                        try await AdminDriverAuthManager.shared
                            .deleteAccount(
                                username: driver.username
                            )

                        loadDrivers()

                    } catch {

                        print(
                            "❌ Secure driver delete failed:",
                            error.localizedDescription
                        )
                    }
                }
            }

            Button("Cancel", role: .cancel) {}

        } message: { driver in

            Text(
                "Delete \(driver.name)? This will permanently remove their driver account and login."
            )
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
        .alert(
            "Password Reset",
            isPresented: $showResetResult
        ) {
            if !temporaryPassword.isEmpty {
                Button("Copy Password") {
                    UIPasteboard.general.string =
                        temporaryPassword
                }
            }

            Button("OK", role: .cancel) {
                temporaryPassword = ""
            }
        } message: {
            Text(resetMessage)
        }
    }
    
    @MainActor
    private func resetDriverPassword(
        _ driver: SupabaseDriver
    ) async {

        guard !isResettingPassword else {
            return
        }

        resetDriver = driver
        isResettingPassword = true

        let newTemporaryPassword =
            generateTemporaryPassword()

        do {

            try await AdminDriverAuthManager.shared
                .resetPassword(
                    username: driver.username,
                    temporaryPassword:
                        newTemporaryPassword
                )

            temporaryPassword =
                newTemporaryPassword

            resetMessage =
                """
                \(driver.name)'s password was reset.

                Temporary Password:
                \(newTemporaryPassword)

                They will be required to change it after logging in.
                """

            showResetResult = true

            loadDrivers()

        } catch {

            temporaryPassword = ""

            resetMessage =
                """
                Password reset failed.

                \(error.localizedDescription)
                """

            showResetResult = true
        }

        isResettingPassword = false
        resetDriver = nil
    }

    private func generateTemporaryPassword() -> String {

        let number =
            Int.random(in: 1000...9999)

        return "Temp-\(number)-X!"
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
    
    @MainActor
    private func createDriver() async {

        guard !isCreatingDriver else {
            return
        }

        let cleanName =
            newName.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        let cleanUsername =
            newUsername
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                .lowercased()

        let cleanTruck =
            newTruck.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard
            !cleanName.isEmpty,
            !cleanUsername.isEmpty,
            !cleanTruck.isEmpty
        else {
            return
        }

        isCreatingDriver = true

        let newTemporaryPassword =
            generateTemporaryPassword()

        do {

            try await AdminDriverAuthManager.shared
                .createAccount(
                    name: cleanName,
                    username: cleanUsername,
                    truckNumber: cleanTruck,
                    role: selectedRole,
                    temporaryPassword:
                        newTemporaryPassword
                )

            temporaryPassword =
                newTemporaryPassword

            resetMessage =
                """
                \(cleanName)'s account was created.

                Username:
                \(cleanUsername)

                Temporary Password:
                \(newTemporaryPassword)

                They will be required to change it after logging in.
                """

            newName = ""
            newTruck = ""
            newUsername = ""
            selectedRole = "driver"

            showResetResult = true

            loadDrivers()

        } catch {

            temporaryPassword = ""

            resetMessage =
                """
                Account creation failed.

                \(error.localizedDescription)
                """

            showResetResult = true
        }

        isCreatingDriver = false
    }
}
