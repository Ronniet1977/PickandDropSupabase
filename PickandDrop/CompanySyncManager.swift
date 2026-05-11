//
//  CompanySyncManager.swift
//  PickandDrop
//
//  Created by Ronald Thayer Jr on 5/11/26.
//
import Foundation
import SwiftData

struct CompanySyncManager {

    static func companyFileURL() -> URL {

        StorageManager
            .truckReportsFolder()
            .appendingPathComponent(
                "CompanyInfo.json"
            )
    }

    static func exportCompany(
        settings: CompanySettings
    ) {

        let file = CompanyFile(

            truckingCompanyName:
                settings.truckingCompanyName,

            pickupCompanyName:
                settings.pickupCompanyName,

            dropoffCompanyName:
                settings.dropoffCompanyName,

            ratePerTon:
                settings.ratePerTon,

            companyJoinCode:
                settings.companyJoinCode
        )

        do {

            let data = try JSONEncoder()
                .encode(file)

            try data.write(
                to: companyFileURL(),
                options: .atomic
            )

            print("✅ CompanyInfo.json exported")

        } catch {

            print("❌ Company export failed:",
                  error)
        }
    }

    static func importCompany() -> CompanyFile? {

        let url = companyFileURL()

        guard FileManager.default.fileExists(
            atPath: url.path
        ) else {

            print("❌ CompanyInfo.json missing")

            return nil
        }

        do {

            let data = try Data(contentsOf: url)

            let file = try JSONDecoder()
                .decode(
                    CompanyFile.self,
                    from: data
                )

            print("✅ Company imported")

            return file

        } catch {

            print("❌ Company import failed:",
                  error)

            return nil
        }
    }
}
