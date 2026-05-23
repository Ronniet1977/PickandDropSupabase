//
//  WeeklyFuelManager.swift
//  PickandDrop
//
//  Created by Ronald Thayer Jr on 5/23/26.
//
import Foundation

struct WeeklyFuelEntry: Codable, Identifiable {

    var id = UUID()
    let driverName: String
    let truckNumber: String

    let amount: Double
    let date: Date
}

enum WeeklyFuelManager {

    static var fileURL: URL {

        StorageManager
            .truckReportsFolder()
            .appendingPathComponent("WeeklyFuel.json")
    }

    static func loadFuelEntries() -> [WeeklyFuelEntry] {

        guard FileManager.default.fileExists(
            atPath: fileURL.path
        ) else {
            return []
        }

        do {

            let data = try Data(contentsOf: fileURL)

            return try JSONDecoder()
                .decode(
                    [WeeklyFuelEntry].self,
                    from: data
                )

        } catch {

            print("❌ Failed loading weekly fuel:", error)

            return []
        }
    }

    static func saveFuelEntries(
        _ entries: [WeeklyFuelEntry]
    ) {

        do {

            let data = try JSONEncoder()
                .encode(entries)

            try data.write(
                to: fileURL,
                options: .atomic
            )

            print("⛽️ Weekly fuel saved")

        } catch {

            print("❌ Failed saving weekly fuel:", error)
        }
    }

    static func addFuel(
        driverName: String,
        truckNumber: String,
        amount: Double
    ) {

        var entries = loadFuelEntries()

        let entry = WeeklyFuelEntry(
            driverName: driverName,
            truckNumber: truckNumber,
            amount: amount,
            date: Date()
        )

        entries.append(entry)

        saveFuelEntries(entries)
    }

    static func totalFuel() -> Double {

        loadFuelEntries()
            .reduce(0.0) {
                $0 + $1.amount
            }
    }

    static func fuelForDriver(
        _ driverName: String
    ) -> Double {

        loadFuelEntries()
            .filter {
                $0.driverName == driverName
            }
            .reduce(0.0) {
                $0 + $1.amount
            }
    }

    static func resetWeeklyFuel() {

        saveFuelEntries([])
    }
}
