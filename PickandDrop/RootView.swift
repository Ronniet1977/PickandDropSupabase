import SwiftUI
import SwiftData

struct RootView: View {
    @Query var drivers: [DriverProfile]
    @AppStorage("currentDriverName") var currentDriverName: String = ""

    var body: some View {
        if let driver = drivers.first(where: { $0.name == currentDriverName }) {
            
            if driver.role == "admin" {
                AdminDashboardView()   // ✅ FIXED
            } else {
                DriverDashboardView(driver: driver)
            }
            
        } else {
            SetupView()
        }
    }
}
