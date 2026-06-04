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

        print("☁️ Using Supabase Company Settings")

        return nil
    }
}
