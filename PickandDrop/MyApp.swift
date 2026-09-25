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
                .task {
                    let granted =
                    await DriverReminderManager.shared
                        .requestPermission()
                    
                    if granted {
                        await DriverReminderManager.shared
                            .scheduleDriverReminders()
                    }
                }
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
