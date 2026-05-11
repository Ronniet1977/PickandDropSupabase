//
//  CompanyFile.swift
//  PickandDrop
//
//  Created by Ronald Thayer Jr on 5/11/26.
//
import Foundation

struct CompanyFile: Codable {

    var truckingCompanyName: String

    var pickupCompanyName: String
    var dropoffCompanyName: String

    var ratePerTon: Double

    var companyJoinCode: String
}
