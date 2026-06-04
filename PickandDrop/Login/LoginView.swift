//
//  LoginView.swift
//  PickandDrop
//
//  Created by Ronald Thayer Jr on 5/8/26.
//
import SwiftUI
import SwiftData

struct LoginView: View {

    @Environment(\.modelContext) private var context

    @Query var companySettings: [CompanySettings]

    @AppStorage("currentDriverName")
    var currentDriverName = ""

    @AppStorage("isLoggedIn")
    var isLoggedIn = false

    @State private var username = ""
    @State private var password = ""

    @State private var loginError = ""
    @AppStorage("mustChangePassword")
    var mustChangePassword = false
    
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

            VStack(spacing: 24) {

                Spacer()

                VStack(spacing: 12) {

                    Image(systemName: "truck.box.fill")
                        .font(.system(size: 70))
                        .foregroundStyle(.white)

                    Text(
                        companySettings.first?.truckingCompanyName
                        ?? "Pick & Drop"
                    )
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)

                    Text(
                        "\(companySettings.first?.pickupCompanyName ?? "Pickup") → \(companySettings.first?.dropoffCompanyName ?? "Dropoff")"
                    )
                        .foregroundStyle(.white.opacity(0.7))
                }

                VStack(spacing: 18) {

                    TextField("Username", text: $username)
                        .textFieldStyle(.roundedBorder)

                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)

                    if !loginError.isEmpty {

                        Text(loginError)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }

                    Button {
                        Task {
                            await login()
                        }
                    } label: {

                        Text("Log In")
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                }
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 28))
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
        }
    }

    func login() async {

        let drivers =
            await DriverSupabaseManager
                .shared
                .fetchDrivers()

        if let driver = drivers.first(where: {

            $0.username.lowercased() ==
            username.lowercased()

            &&

            ($0.password ?? "") == password

            &&

            $0.is_active

        }) {
            let localDriver = DriverProfile()
            localDriver.name = driver.name
            localDriver.username = driver.username
            localDriver.password = driver.password ?? ""
            localDriver.truckNumber = driver.truck_number
            localDriver.role = driver.role
            localDriver.isActive = driver.is_active
            localDriver.mustChangePassword = false

            context.insert(localDriver)

            try? context.save()

            currentDriverName = driver.name

            // Admin never forced to change password
            mustChangePassword = false

            isLoggedIn = true

            print("✅ Login success")

        } else {

            loginError = "Invalid username or password"
        }
    }
}
