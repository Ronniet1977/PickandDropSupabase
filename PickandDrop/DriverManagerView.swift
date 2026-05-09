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

    @Query(sort: \DriverProfile.name)
    var drivers: [DriverProfile]
    
    @AppStorage("currentDriverName")
    var currentDriverName = ""

    @State private var newName = ""
    @State private var newTruck = ""
    @State private var newUsername = ""

    @State private var selectedRole = "driver"

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

                            VStack(alignment: .leading, spacing: 12) {

                                HStack {

                                    VStack(alignment: .leading) {

                                        Text(driver.name)
                                            .font(.headline)
                                            .foregroundStyle(.white)

                                        Text(
                                            "@\(driver.username)"
                                        )
                                        .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    Text(driver.role.capitalized)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(
                                            driver.role == "admin"
                                            ? .red.opacity(0.2)
                                            : .blue.opacity(0.2)
                                        )
                                        .foregroundStyle(
                                            driver.role == "admin"
                                            ? .red
                                            : .blue
                                        )
                                        .clipShape(Capsule())
                                }

                                HStack {
                                    Button("Reset Password") {

                                        driver.password = "1234"
                                        driver.mustChangePassword = true

                                        try? context.save()
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.orange)

                                    Button(
                                        driver.isActive
                                        ? "Disable"
                                        : "Enable"
                                    ) {

                                        driver.isActive.toggle()

                                        try? context.save()
                                    }
                                    
                                    Button(role: .destructive) {

                                        deleteDriver(driver)

                                    } label: {

                                        Label(
                                            "Delete",
                                            systemImage: "trash.fill"
                                        )
                                    }
                                    .disabled(driver.name == currentDriverName)
                                    .buttonStyle(.borderedProminent)
                                    .tint(.red)
                                    
                                    .buttonStyle(.borderedProminent)
                                    .tint(
                                        driver.isActive
                                        ? .red
                                        : .green
                                    )
                                }
                            }
                            .padding()
                            .background(.ultraThinMaterial)
                            .clipShape(
                                RoundedRectangle(cornerRadius: 24)
                            )
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
                    Button(role: .destructive) {
                        deleteTestDrivers()
                    } label: {
                        Label(
                            "Delete Test Drivers",
                            systemImage: "trash.fill"
                        )
                    }
                } label: {
                    Image(systemName: "ellipsis.circle.fill")
                        .font(.title3)
                }
            }
        }
    }

    func createDriver() {

        let driver = DriverProfile()

        driver.name = newName
        driver.truckNumber = newTruck

        driver.username = newUsername.lowercased()

        driver.password = "1234"

        driver.role = selectedRole

        driver.mustChangePassword = true

        context.insert(driver)

        do {

            try context.save()

            newName = ""
            newTruck = ""
            newUsername = ""

            selectedRole = "driver"

            print("✅ Driver created")

        } catch {

            print("❌ Failed creating driver:", error)
        }
    }
    
    func deleteDriver(_ driver: DriverProfile) {

        context.delete(driver)

        do {

            try context.save()

            print("✅ Driver deleted")

        } catch {

            print("❌ Failed deleting driver:", error)
        }
    }
    
    func deleteTestDrivers() {

        for driver in drivers {

            if driver.name != currentDriverName {

                context.delete(driver)
            }
        }

        do {

            try context.save()

            print("✅ Test drivers deleted")

        } catch {

            print("❌ Failed deleting:", error)
        }
    }
}
