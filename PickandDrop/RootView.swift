import SwiftUI
import SwiftData

struct RootView: View {
    @Query var drivers: [DriverProfile]
    @AppStorage("currentDriverName") var currentDriverName: String = ""
    @AppStorage("hasSetup") var hasSetup = false
    
    var body: some View {
        if hasSetup,
           let driver = drivers.first(where: { $0.name == currentDriverName }) {

            if driver.role == "admin" {
                AdminDashboardView()
            } else {
                DriverDashboardView(driver: driver)
            }

        } else {
            SetupView()
        }
    }
}
