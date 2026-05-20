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
            
            guard !file.drivers.isEmpty else {

                print("❌ Refusing empty driver import")

                return
            }

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
                driver.mustChangePassword =
                    record.mustChangePassword ?? false

                context.insert(driver)
            }

            try context.save()

            print("✅ Drivers imported")

        } catch {

            print("❌ Driver import failed:", error)
        }
    }
    
    static func updateDriverInSharedFile(driver: DriverProfile) {

        let url = driverFileURL()

        do {
            let data = try Data(contentsOf: url)

            var file = try JSONDecoder()
                .decode(DriverFile.self, from: data)

            if let index = file.drivers.firstIndex(where: {
                $0.username.lowercased() == driver.username.lowercased()
            }) {
                file.drivers[index].password = driver.password
                file.drivers[index].mustChangePassword = driver.mustChangePassword
                file.drivers[index].isActive = driver.isActive
            }

            let newData = try JSONEncoder().encode(file)

            try newData.write(to: url, options: .atomic)

            print("✅ Shared driver updated")

        } catch {
            print("❌ Failed updating shared driver:", error)
        }
    }

    static func exportDrivers(
        drivers: [DriverProfile]
    ) {
        guard !drivers.isEmpty else {

            print("❌ Refusing empty export")

            return
        }

        guard drivers.contains(where: {
            $0.role == "admin"
        }) else {

            print("❌ No admin found — refusing export")

            return
        }

        let records = drivers.map {

            DriverRecord(
                name: $0.name,
                truckNumber: $0.truckNumber,
                username: $0.username,
                password: $0.password,
                role: $0.role,
                isActive: $0.isActive,
                mustChangePassword: $0.mustChangePassword
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
