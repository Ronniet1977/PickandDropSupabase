//
//  DriverFile.swift
//  PickandDrop
//
//  Created by Ronald Thayer Jr on 5/10/26.
//
import Foundation

struct DriverFile: Codable {

    var drivers: [DriverRecord]
}

struct DriverRecord: Codable, Identifiable {

    var id = UUID()

    var name: String
    var truckNumber: String

    var username: String
    var password: String

    var role: String
    var isActive: Bool

    var mustChangePassword: Bool?
}
