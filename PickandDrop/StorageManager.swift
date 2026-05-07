import Foundation

struct StorageManager {
    static let folderBookmarkKey = "TruckReportsFolderBookmark"
    
    static func saveTruckReportsFolder(_ url: URL) {
        do {
            let bookmark = try url.bookmarkData(
                options: .minimalBookmark,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            
            UserDefaults.standard.set(bookmark, forKey: folderBookmarkKey)
            print("✅ Saved Truck Reports folder:", url.path)
        } catch {
            print("❌ Bookmark save failed:", error)
        }
    }
    
    static func truckReportsFolder() -> URL {
        if let data = UserDefaults.standard.data(forKey: folderBookmarkKey) {
            do {
                var stale = false
                let url = try URL(
                    resolvingBookmarkData: data,
                    options: [],
                    relativeTo: nil,
                    bookmarkDataIsStale: &stale
                )
                
                _ = url.startAccessingSecurityScopedResource()
                
                try FileManager.default.createDirectory(
                    at: url,
                    withIntermediateDirectories: true
                )
                
                return url
            } catch {
                print("❌ Bookmark failed:", error)
            }
        }
        
        let local = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Truck Reports")
        
        try? FileManager.default.createDirectory(
            at: local,
            withIntermediateDirectories: true
        )
        
        return local
    }
}

// build refresh 2
