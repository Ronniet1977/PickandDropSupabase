//
//  CSVLoad.swift
//  PickandDrop
//
//  Created by Ronald Thayer Jr on 5/7/26.
//

import Foundation

struct CSVLoad: Identifiable {

    let id = UUID()

    let date: String
    let time: String

    let driverName: String
    let truck: String

    let pickupTicket: String
    let pickupTons: Double

    let deliveryTicket: String
    let deliveryTons: Double

    let pickedUp: String
    let delivered: String

    var isDelivered: Bool {
        !deliveryTicket.isEmpty &&
        deliveryTicket != "Not delivered"
    }
}
