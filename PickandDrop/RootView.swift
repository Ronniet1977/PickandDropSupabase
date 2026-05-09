import SwiftUI
import SwiftData

struct RootView: View {

    @Query var drivers: [DriverProfile]

    @AppStorage("currentDriverName")
    var currentDriverName: String = ""
    
    @AppStorage("mustChangePassword")
    var mustChangePassword = false

    @AppStorage("isLoggedIn")
    var isLoggedIn = false

    var body: some View {

        if isLoggedIn,
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
}
