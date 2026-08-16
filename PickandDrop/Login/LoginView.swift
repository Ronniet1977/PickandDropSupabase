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

    @AppStorage("currentDriverName")
    var currentDriverName = ""

    @AppStorage("isLoggedIn")
    var isLoggedIn = false
    
    @State private var settings: SupabaseCompanySettings?

    @State private var username = ""
    @State private var password = ""
    @State private var showJoinCompany = false

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
                        settings?.trucking_company_name
                        ?? "Pick & Drop"
                    )
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)

                    Text(
                        "\(settings?.pickup_company_name ?? "Pickup") → \(settings?.dropoff_company_name ?? "Dropoff")"
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

                    Button("Join Company") {
                        showJoinCompany = true
                    }
                    .foregroundStyle(.white)
                }
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 28))
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
        }
        .onAppear {

            Task {

                let loadedSettings =
                    await CompanySupabaseManager.shared
                        .fetchCompanySettings()

                await MainActor.run {
                    settings = loadedSettings
                }
            }
        }
        .sheet(isPresented: $showJoinCompany) {
            JoinCompanyView()
        }
    }
    

    func login() async {

        let cleanUsername =
            username
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                .lowercased()

        let cleanPassword =
            password.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !cleanUsername.isEmpty,
              !cleanPassword.isEmpty
        else {
            await MainActor.run {
                loginError =
                    "Enter your username and password"
            }
            return
        }

        let authEmail =
            "\(cleanUsername)@pickanddrop.local"

        do {

            // 1. Authenticate password securely with Supabase Auth
            _ = try await SupabaseAuthManager.shared.signIn(
                email: authEmail,
                password: cleanPassword
            )

            // 2. Load the driver's Pick & Drop profile
            guard let driver =
                await DriverSupabaseManager.shared.fetchDriver(
                    username: cleanUsername
                )
            else {
                SupabaseAuthManager.shared.clearSession()

                await MainActor.run {
                    loginError =
                        "Driver profile not found"
                }

                return
            }

            // 3. Block disabled accounts
            guard driver.is_active else {
                SupabaseAuthManager.shared.clearSession()

                await MainActor.run {
                    loginError =
                        "This account is disabled"
                }

                return
            }

            // 4. Update/create local SwiftData profile
            let existingDriver =
                try? context.fetch(
                    FetchDescriptor<DriverProfile>()
                )
                .first {
                    $0.username.lowercased()
                        == driver.username.lowercased()
                }

            let localDriver =
                existingDriver ?? DriverProfile()

            localDriver.name =
                driver.name

            localDriver.username =
                driver.username

            // Do NOT save the actual password locally anymore.
            localDriver.truckNumber =
                driver.truck_number

            localDriver.role =
                driver.role

            localDriver.isActive =
                driver.is_active

            localDriver.mustChangePassword =
                driver.must_change_password ?? true

            if existingDriver == nil {
                context.insert(localDriver)
            }

            try? context.save()

            await MainActor.run {

                currentDriverName =
                    driver.name

                mustChangePassword =
                    driver.must_change_password ?? true

                loginError = ""

                isLoggedIn = true

                password = ""
            }

            print(
                "✅ Secure Auth login:",
                driver.username
            )

        } catch {

            SupabaseAuthManager.shared.clearSession()

            await MainActor.run {
                loginError =
                    "Invalid username or password"
            }

            print(
                "❌ Secure Auth login failed:",
                error.localizedDescription
            )
        }
    }
}
