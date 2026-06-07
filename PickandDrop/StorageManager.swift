import Foundation

struct StorageManager {

    static func truckReportsFolder() -> URL {

        let local = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PickandDrop")
            .appendingPathComponent("Reports")

        try? FileManager.default.createDirectory(
            at: local,
            withIntermediateDirectories: true
        )

        return local
    }
}
