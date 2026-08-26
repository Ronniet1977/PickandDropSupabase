import SwiftUI
import SwiftData

struct RootView: View {
    
    @Query var drivers: [DriverProfile]
    @Query var shifts: [Shift]
    
    @State private var checkedAuthSession = false
    
    @AppStorage("currentDriverName")
    var currentDriverName: String = ""
    
    @AppStorage("mustChangePassword")
    var mustChangePassword = false
    
    @AppStorage("isLoggedIn")
    var isLoggedIn = false
    
    @AppStorage("didMigrateLegacyShifts")
    private var didMigrateLegacyShifts = false
    
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
                        .task {
                            await migrateLegacyShiftsIfNeeded()
                        }
                    
                } else {
                    
                    DriverDashboardView(
                        driver: driver
                    )
                    .task {
                        await migrateLegacyShiftsIfNeeded()
                    }
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
    private func migrateLegacyShiftsIfNeeded() async {
        
        guard !didMigrateLegacyShifts else {
            return
        }
        
        let success =
        await LegacyShiftMigrationManager.shared
            .migrate(
                shifts: shifts,
                drivers: drivers
            )
        
        if success {
            
            didMigrateLegacyShifts = true
            
            print(
                "✅ Device legacy shift migration marked complete"
            )
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
