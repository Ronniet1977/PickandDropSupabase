import SwiftUI
import SwiftData

struct RootView: View {

    @Query var drivers: [DriverProfile]
    @Query var companySettings: [CompanySettings]
    
    @State private var checkedCompany = false
    @State private var hasCompanyInSupabase = false

    @AppStorage("currentDriverName")
    var currentDriverName: String = ""
    
    @AppStorage("mustChangePassword")
    var mustChangePassword = false

    @AppStorage("isLoggedIn")
    var isLoggedIn = false
    
    var settings: CompanySettings? {
        companySettings.first
    }

    var body: some View {

        Group {

            if !checkedCompany {

                ProgressView("Loading...")

            } else if !hasCompanyInSupabase {

                CompanySetupView {
                    Task {
                        let company =
                            await CompanySupabaseManager.shared.fetchCompanySettings()

                        await MainActor.run {
                            hasCompanyInSupabase = company != nil
                            checkedCompany = true
                        }
                    }
                }

            } else if isLoggedIn,
                      let driver = drivers.first(where: {
                          $0.name == currentDriverName
                      }) {

                if mustChangePassword {

                    ChangePasswordView(driver: driver)

                } else {

                    if driver.role == "admin" {

                        AdminDashboardView()

                    } else {

                        DriverDashboardView(driver: driver)
                    }
                }

            } else {

                LoginView()
            }
        }
        .onAppear {

            Task {

                let company =
                    await CompanySupabaseManager.shared.fetchCompanySettings()

                await MainActor.run {

                    hasCompanyInSupabase = company != nil
                    checkedCompany = true

                    if company == nil {

                        currentDriverName = ""
                        isLoggedIn = false
                        mustChangePassword = false
                    }
                }
            }
        }
    }
}
