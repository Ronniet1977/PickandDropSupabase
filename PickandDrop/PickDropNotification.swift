//
//  PickDropNotification.swift
//  PickandDrop
//
//  Created by Ronald Thayer Jr on 6/4/26.
//

import Foundation

struct PickDropNotification: Codable, Identifiable {

    let id: UUID?

    let type: String
    let driver_name: String
    let truck_number: String
    let message: String
    let load_ticket: String?

    let created_at: String?
}

