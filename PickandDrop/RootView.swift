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
    
    @State private var updateRequired = false
    @State private var updateURL: URL?
    
    var body: some View {
        
        Group {
            
            if updateRequired {
                
                VStack(spacing: 24) {
                    
                    Image(
                        systemName:
                            "arrow.down.circle.fill"
                    )
                    .font(.system(size: 70))
                    .foregroundStyle(.blue)
                    
                    Text("Update Required")
                        .font(.largeTitle.bold())
                    
                    Text(
                        "A newer version of Pick & Drop is required to continue."
                    )
                    .multilineTextAlignment(.center)
                    
                    if let updateURL {
                        
                        Link(
                            "Update App",
                            destination: updateURL
                        )
                        .buttonStyle(
                            .borderedProminent
                        )
                    }
                }
                .padding()
                
            } else if !checkedAuthSession {
                
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
            await checkForRequiredUpdate()
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
    private func checkForRequiredUpdate() async {
        
#if DEBUG
        
        print("🛠 DEBUG build — update gate bypassed")
        
        updateRequired = false
        updateURL = nil
        
        return
        
#else
        
        guard let config =
                await AppUpdateManager.shared
            .fetchConfig()
        else {
            return
        }
        
        let currentBuild =
        Int(
            Bundle.main.object(
                forInfoDictionaryKey:
                    "CFBundleVersion"
            ) as? String ?? "0"
        ) ?? 0
        
        print("📱 Current build:", currentBuild)
        print("🚧 Minimum build:", config.minimum_build)
        print("🆕 Latest build:", config.latest_build)
        print("🔒 Force update:", config.force_update)
        
        if config.force_update &&
            currentBuild < config.minimum_build {
            
            updateRequired = true
            
            if let urlString =
                config.app_store_url {
                
                updateURL =
                URL(
                    string: urlString
                )
            }
            
        } else {
            
            updateRequired = false
            updateURL = nil
        }
        
#endif
    }
    
    @MainActor
    private func startup() async {
        
        if isLoggedIn {
            
            let result =
            await SupabaseAuthManager.shared
                .restoreSession()
            
            switch result {
                
            case .restored:
                
                print(
                    "✅ Existing login session restored"
                )
                
            case .temporaryFailure:
                
                // IMPORTANT:
                // Keep the driver's local login.
                // Do not throw Jesse back to LoginView
                // just because the network had a bad moment.
                
                print(
                    "⚠️ Auth temporarily unavailable — keeping saved login"
                )
                
            case .noSession,
                    .invalidSession:
                
                print(
                    "⚠️ No valid saved Auth session"
                )
                
                currentDriverName = ""
                isLoggedIn = false
                mustChangePassword = false
            }
        }
        
        checkedAuthSession = true
    }
}
