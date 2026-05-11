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
