//
//  HelpView.swift
//  PickandDrop
//
//  Created by Ronald Thayer Jr on 5/20/26.
//

import SwiftUI

struct HelpView: View {

    var body: some View {

        NavigationStack {

            List {

                Section("Initial Setup") {

                    helpRow(
                        icon: "building.2.fill",
                        title: "Create Company",
                        text: "Enter the trucking company, pickup company, drop-off company, rate per ton, admin login, and shared folder."
                    )

                    helpRow(
                        icon: "folder.fill",
                        title: "Shared Folder",
                        text: "Choose the shared iCloud Drive folder. This is where reports, driver files, fuel receipts, invoices, and sync files are saved."
                    )

                    helpRow(
                        icon: "person.badge.key.fill",
                        title: "Admin Account",
                        text: "The first setup creates the admin account. Admins can create drivers, reset passwords, disable users, view reports, and open driver files."
                    )
                }

                Section("Driver Setup") {

                    helpRow(
                        icon: "person.fill",
                        title: "Create Drivers",
                        text: "Admin creates each driver with a username and default password. Drivers are saved to Drivers.json in the shared folder."
                    )

                    helpRow(
                        icon: "key.fill",
                        title: "First Login",
                        text: "Drivers log in with the username and password provided by admin. If required, they must change their password before using the app."
                    )

                    helpRow(
                        icon: "folder.badge.plus",
                        title: "Join Existing Company",
                        text: "On a new device, choose Join Existing Company, select the shared folder, and the company information will load automatically."
                    )
                }

                Section("Daily Use") {

                    helpRow(
                        icon: "play.circle.fill",
                        title: "Start Day",
                        text: "Driver starts their shift before adding loads."
                    )

                    helpRow(
                        icon: "shippingbox.fill",
                        title: "Add Load",
                        text: "Driver enters pickup ticket and pickup tons."
                    )

                    helpRow(
                        icon: "arrow.down.circle.fill",
                        title: "Deliver Load",
                        text: "Driver completes the delivery by entering the drop-off ticket and delivery tons."
                    )

                    helpRow(
                        icon: "fuelpump.fill",
                        title: "Fuel Receipt",
                        text: "When adding fuel, driver can take a receipt photo. It saves under Drivers / Driver Name / Fuel Receipts."
                    )
                }

                Section("Admin Tools") {

                    helpRow(
                        icon: "chart.bar.fill",
                        title: "Dashboard",
                        text: "Admin can refresh live data, view driver totals, see open loads, delivered loads, fuel totals, and ton differences."
                    )

                    helpRow(
                        icon: "doc.text.fill",
                        title: "Reports",
                        text: "CSV reports and invoices are stored in the shared folder and can be reviewed from the Reports tab."
                    )

                    helpRow(
                        icon: "folder.fill",
                        title: "Driver Files",
                        text: "The folder button opens the shared Drivers folder, including receipt photos and future driver documents."
                    )

                    helpRow(
                        icon: "trash.fill",
                        title: "Archive & Reset",
                        text: "Clears active loads and shifts but keeps final reports and saved driver files."
                    )
                }
            }
            .navigationTitle("Help")
        }
    }

    private func helpRow(
        icon: String,
        title: String,
        text: String
    ) -> some View {

        HStack(alignment: .top, spacing: 14) {

            Image(systemName: icon)
                .foregroundStyle(.blue)
                .font(.title3)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {

                Text(title)
                    .font(.headline)

                Text(text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}
