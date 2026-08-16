import SwiftUI
import SwiftData

struct RootView: View {

    @Query var drivers: [DriverProfile]

    @State private var checkedAuthSession = false

    @AppStorage("currentDriverName")
    var currentDriverName: String = ""

    @AppStorage("mustChangePassword")
    var mustChangePassword = false

    @AppStorage("isLoggedIn")
    var isLoggedIn = false

    var body: some View {

        Group {

            if !checkedAuthSession {

                ProgressView("Loading...")

            } else if isLoggedIn,
                      let driver = drivers.first(where: {
                          $0.name == currentDriverName
                      }) {

                if mustChangePassword {

                    ChangePasswordView(
                        driver: driver
                    )

                } else if driver.role == "admin" {

                    AdminDashboardView()

                } else {

                    DriverDashboardView(
                        driver: driver
                    )
                }

            } else {

                LoginView()
            }
        }
        .task {
            await startup()
        }
    }

    @MainActor
    private func startup() async {

        if isLoggedIn {

            let restored =
                await SupabaseAuthManager.shared
                    .restoreSession()

            if restored {

                print(
                    "✅ Existing login session restored"
                )

            } else {

                print(
                    "⚠️ Saved app login had no valid Auth session"
                )

                currentDriverName = ""
                isLoggedIn = false
                mustChangePassword = false
            }
        }

        checkedAuthSession = true
    }
}
