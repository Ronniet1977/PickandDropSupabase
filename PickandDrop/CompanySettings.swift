//
//  CompanySettings.swift
//  PickandDrop
//
//  Created by Ronald Thayer Jr on 5/10/26.
//

import Foundation
import SwiftData

@Model
class CompanySettings {

    var truckingCompanyName: String = ""
    var companyJoinCode: String = ""

    var pickupCompanyName: String = ""
    var dropoffCompanyName: String = ""

    var ratePerTon: Double = 0

    var sharedFolderPath: String = ""

    init() {}
}
