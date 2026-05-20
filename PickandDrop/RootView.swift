import SwiftUI
import SwiftData

struct RootView: View {

    @Query var drivers: [DriverProfile]
    @Query var companySettings: [CompanySettings]
    

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

        if settings == nil {

            CompanySetupView()

        }
        else if !StorageManager.hasSharedFolder() {

            SharedFolderSetupView()
        }
        else if isLoggedIn,
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
                .onAppear {

                    if drivers.first(where: {
                        $0.name == currentDriverName
                    }) == nil {

                        currentDriverName = ""
                        isLoggedIn = false
                        mustChangePassword = false
                    }
                }
        }
    }
}
