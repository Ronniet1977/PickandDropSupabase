import SwiftUI
import SwiftData

@main
struct PickandDrop: App {
    init() {
        _ = StorageManager.truckReportsFolder()
    }
    
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(
            for: [
                DriverProfile.self,
                Shift.self,
                LoadItem.self,
                CompanySettings.self
            ],
            inMemory: false,
            isAutosaveEnabled: true,
            isUndoEnabled: true
        )
    }
}
