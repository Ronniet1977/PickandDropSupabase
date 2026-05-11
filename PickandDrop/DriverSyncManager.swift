//
//  DriverSyncManager.swift
//  PickandDrop
//
//  Created by Ronald Thayer Jr on 5/10/26.
//

import Foundation
import SwiftData

struct DriverSyncManager {

    static func driverFileURL() -> URL {

        StorageManager
            .truckReportsFolder()
            .appendingPathComponent("Drivers.json")
    }
    
    static func importDrivers(
        context: ModelContext
    ) {

        let url = driverFileURL()

        guard FileManager.default.fileExists(
            atPath: url.path
        ) else {

            print("❌ Drivers.json missing")
            return
        }

        do {

            let data = try Data(contentsOf: url)

            let file = try JSONDecoder()
                .decode(
                    DriverFile.self,
                    from: data
                )

            // REMOVE OLD LOCAL DRIVERS
            let descriptor =
                FetchDescriptor<DriverProfile>()

            let existingDrivers =
                try context.fetch(descriptor)

            for driver in existingDrivers {

                context.delete(driver)
            }

            // IMPORT NEW DRIVERS
            for record in file.drivers {

                let driver = DriverProfile()

                driver.name = record.name
                driver.truckNumber = record.truckNumber

                driver.username = record.username
                driver.password = record.password

                driver.role = record.role
                driver.isActive = record.isActive

                context.insert(driver)
            }

            try context.save()

            print("✅ Drivers imported")

        } catch {

            print("❌ Driver import failed:", error)
        }
    }

    static func exportDrivers(
        drivers: [DriverProfile]
    ) {

        let records = drivers.map {

            DriverRecord(
                name: $0.name,
                truckNumber: $0.truckNumber,
                username: $0.username,
                password: $0.password,
                role: $0.role,
                isActive: $0.isActive
            )
        }

        let file = DriverFile(drivers: records)

        do {

            let data = try JSONEncoder()
                .encode(file)

            try data.write(
                to: driverFileURL(),
                options: .atomic
            )

            print("✅ Drivers.json exported")

        } catch {

            print("❌ Driver export failed:", error)
        }
    }
}
