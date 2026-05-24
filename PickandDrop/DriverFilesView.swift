//
//  DriverFilesView.swift
//  PickandDrop
//
//  Created by Ronald Thayer Jr on 5/20/26.
//

import SwiftUI
import UIKit

enum AppTheme {

    static let cardBackground =
        Color.blue.opacity(0.12)

    static let accent =
        Color.blue

    static let success =
        Color.green

    static let warning =
        Color.orange
}

struct DriverFilesView: View {

    @State private var driverFolders: [URL] = []

    var body: some View {

        NavigationStack {

            List {
                Section("Admin Files") {
                    NavigationLink("Company Info") {
                        CompanyInfoCardView()
                    }

                    NavigationLink("Drivers") {
                        DriversCardView()
                    }

                    NavigationLink("Weekly Fuel") {
                        WeeklyFuelCardsView()
                    }

                    NavigationLink("Driver Sessions") {
                        DriverSessionsCardView()
                    }

                    NavigationLink("Fuel Archives") {
                        FuelArchiveListView()
                    }
                }
                .listRowBackground(AppTheme.cardBackground)

                ForEach(driverFolders, id: \.self) { folder in
                    NavigationLink {
                        DriverFolderDetailView(folder: folder)
                    } label: {
                        Label(folder.lastPathComponent, systemImage: "person.fill")
                    }
                    .listRowBackground(AppTheme.cardBackground)
                }
            }
            .scrollContentBackground(.hidden)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.08, green: 0.11, blue: 0.18),
                        Color(red: 0.15, green: 0.22, blue: 0.35),
                        Color.black.opacity(0.95)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .navigationTitle("Driver Files")
            .onAppear {
                loadDriverFolders()
            }
        }
    }

    func loadDriverFolders() {

        let driversFolder =
            StorageManager
                .truckReportsFolder()
                .appendingPathComponent("Drivers")

        do {

            driverFolders =
                try FileManager.default
                    .contentsOfDirectory(
                        at: driversFolder,
                        includingPropertiesForKeys: nil
                    )
                    .filter { $0.hasDirectoryPath }

        } catch {

            print(
                "❌ Failed loading driver folders:",
                error
            )
        }
    }
}

struct DriverFolderDetailView: View {

    let folder: URL

    @State private var files: [URL] = []

    var body: some View {

        List {

            ForEach(files, id: \.self) { file in

                if file.hasDirectoryPath {

                    NavigationLink {

                        DriverSubfolderView(folder: file)

                    } label: {

                        Label(
                            file.lastPathComponent,
                            systemImage: "folder.fill"
                        )
                    }

                } else {

                    VStack(alignment: .leading) {

                        Text(file.lastPathComponent)
                            .font(.headline)

                        Text(file.path)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }        }
        .navigationTitle(folder.lastPathComponent)
        .onAppear {
            loadFiles()
        }
    }

    func loadFiles() {

        do {

            files =
                try FileManager.default
                    .contentsOfDirectory(
                        at: folder,
                        includingPropertiesForKeys: nil
                    )

        } catch {

            print(
                "❌ Failed loading files:",
                error
            )
        }
    }
}

struct DriverSubfolderView: View {

    let folder: URL

    @State private var files: [URL] = []

    var body: some View {

        List {

            ForEach(files, id: \.self) { file in

                if let image = UIImage(contentsOfFile: file.path) {

                    VStack(alignment: .leading, spacing: 10) {

                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 260)
                            .clipShape(RoundedRectangle(cornerRadius: 18))

                        Text(file.lastPathComponent)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)

                } else {

                    Text(file.lastPathComponent)
                }
            }
        }
        .navigationTitle(folder.lastPathComponent)
        .onAppear {
            loadFiles()
        }
    }

    func loadFiles() {

        do {

            files =
                try FileManager.default
                    .contentsOfDirectory(
                        at: folder,
                        includingPropertiesForKeys: nil
                    )

        } catch {

            print(
                "❌ Failed loading subfolder:",
                error
            )
        }
    }
}

struct FilePreviewView: View {

    let fileURL: URL

    @State private var text = ""

    var body: some View {
        ScrollView {
            Text(text)
                .font(.system(.caption, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .navigationTitle(fileURL.lastPathComponent)
        .onAppear {
            loadText()
        }
    }

    func loadText() {
        do {
            text = try String(contentsOf: fileURL, encoding: .utf8)
        } catch {
            text = "Could not read file:\n\(fileURL.lastPathComponent)"
        }
    }
}

//Cards
struct WeeklyFuelCardsView: View {

    @State private var entries: [WeeklyFuelEntry] = []

    var totalFuel: Double {
        entries.reduce(0) { $0 + $1.amount }
    }

    var body: some View {

        ScrollView {

            VStack(spacing: 16) {

                VStack(alignment: .leading, spacing: 8) {

                    Text("Weekly Fuel")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("$\(totalFuel, specifier: "%.2f")")
                        .font(.largeTitle.bold())

                    Text("\(entries.count) fuel entries")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 24))

                ForEach(entries) { entry in

                    VStack(alignment: .leading, spacing: 10) {

                        HStack {

                            VStack(alignment: .leading, spacing: 4) {

                                Text(entry.driverName)
                                    .font(.headline)

                                Text("Truck \(entry.truckNumber)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text("$\(entry.amount, specifier: "%.2f")")
                                .font(.title3.bold())
                                .foregroundStyle(AppTheme.success)
                        }

                        Text(
                            entry.date.formatted(
                                date: .abbreviated,
                                time: .shortened
                            )
                        )
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                }
            }
            .padding()
        }
        .navigationTitle("Weekly Fuel")
        .onAppear {
            entries = WeeklyFuelManager.loadFuelEntries()
                .sorted { $0.date > $1.date }
        }
    }
}

struct CompanySettingsDTO: Codable {

    let truckingCompanyName: String
    let pickupCompanyName: String
    let dropoffCompanyName: String
    let companyJoinCode: String
    let ratePerTon: Double
}

struct CompanyInfoCardView: View {

    @State private var settings: CompanySettingsDTO?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {

                if let settings {

                    VStack(alignment: .leading, spacing: 14) {
                        Text(settings.truckingCompanyName)
                            .font(.largeTitle.bold())

                        Label(settings.pickupCompanyName, systemImage: "arrow.up.circle.fill")
                        Label(settings.dropoffCompanyName, systemImage: "arrow.down.circle.fill")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 24))

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Join Company Code")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(settings.companyJoinCode)
                            .font(.title2.bold())
                            .foregroundStyle(AppTheme.accent)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.blue.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 18))

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Rate Per Ton")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("$\(settings.ratePerTon, specifier: "%.2f")")
                            .font(.title2.bold())
                            .foregroundStyle(AppTheme.success)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.green.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 18))

                } else {
                    Text("No company info found")
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .navigationTitle("Company Info")
        .onAppear {
            loadCompanyInfo()
        }
    }

    func loadCompanyInfo() {
        let url = StorageManager.truckReportsFolder()
            .appendingPathComponent("CompanyInfo.json")

        do {
            let data = try Data(contentsOf: url)

            settings = try JSONDecoder()
                .decode(CompanySettingsDTO.self, from: data)

        } catch {
            print("❌ Failed loading company info:", error)
        }
    }
}

struct DriversDTO: Codable {
    let drivers: [DriverDTO]
}

struct DriverDTO: Codable, Identifiable {

    let id: String
    let name: String
    let truckNumber: String
    let role: String
    let username: String
    let isActive: Bool
}

struct DriversCardView: View {

    @State private var drivers: [DriverDTO] = []

    var body: some View {

        ScrollView {

            VStack(spacing: 16) {

                ForEach(drivers) { driver in

                    VStack(alignment: .leading, spacing: 12) {

                        HStack {

                            VStack(alignment: .leading, spacing: 4) {

                                Text(driver.name)
                                    .font(.title2.bold())

                                Text("Truck \(driver.truckNumber)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text(driver.role.uppercased())
                                .font(.caption.bold())
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    driver.role == "admin"
                                    ? Color.blue.opacity(0.15)
                                    : Color.green.opacity(0.15)
                                )
                                .foregroundStyle(
                                    driver.role == "admin"
                                    ? .blue
                                    : .green
                                )
                                .clipShape(Capsule())
                        }

                        HStack {

                            Label(
                                driver.username,
                                systemImage: "person.fill"
                            )

                            Spacer()

                            Label(
                                driver.isActive
                                ? "Active"
                                : "Inactive",
                                systemImage:
                                    driver.isActive
                                    ? "checkmark.circle.fill"
                                    : "xmark.circle.fill"
                            )
                            .foregroundStyle(
                                driver.isActive
                                ? .green
                                : .red
                            )
                        }
                        .font(.caption)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                }
            }
            .padding()
        }
        .navigationTitle("Drivers")
        .onAppear {
            loadDrivers()
        }
    }

    func loadDrivers() {

        let url = StorageManager.truckReportsFolder()
            .appendingPathComponent("Drivers.json")

        do {

            let data = try Data(contentsOf: url)

            let decoded = try JSONDecoder()
                .decode(DriversDTO.self, from: data)

            drivers = decoded.drivers

        } catch {

            print("❌ Failed loading drivers:", error)
        }
    }
}

struct DriverSessionsDTO: Codable {
    let sessions: [DriverSessionDTO]
}

struct DriverSessionDTO: Codable, Identifiable {

    var id: UUID { UUID() }

    let loginTime: Double
    let username: String
    let deviceName: String
}

struct DriverSessionsCardView: View {

    @State private var sessions: [DriverSessionDTO] = []

    var body: some View {

        ScrollView {

            VStack(spacing: 16) {

                ForEach(sessions.indices, id: \.self) { index in

                    let session = sessions[index]

                    VStack(alignment: .leading, spacing: 12) {

                        HStack {

                            VStack(alignment: .leading, spacing: 4) {

                                Text(session.username.capitalized)
                                    .font(.title3.bold())

                                Text(session.deviceName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "ipad.and.iphone")
                                .font(.title2)
                                .foregroundStyle(AppTheme.accent)
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 4) {

                            Text("Login Time")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text(
                                Date(timeIntervalSinceReferenceDate: session.loginTime)
                                    .formatted(
                                        date: .abbreviated,
                                        time: .shortened
                                    )
                            )
                            .font(.headline)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                }
            }
            .padding()
        }
        .navigationTitle("Driver Sessions")
        .onAppear {
            loadSessions()
        }
    }

    func loadSessions() {

        let url = StorageManager.truckReportsFolder()
            .appendingPathComponent("DriverSessions.json")

        do {

            let data = try Data(contentsOf: url)

            let decoded = try JSONDecoder()
                .decode(DriverSessionsDTO.self, from: data)

            sessions = decoded.sessions

        } catch {

            print("❌ Failed loading sessions:", error)
        }
    }
}

struct FuelArchiveListView: View {

    @State private var archiveFiles: [URL] = []

    var body: some View {

        List {

            // ✅ Current Week
            Section("Current Week") {

                NavigationLink {

                    FuelArchivePrettyView(
                        fileURL: StorageManager
                            .truckReportsFolder()
                            .appendingPathComponent("WeeklyFuel.json")
                    )

                } label: {

                    Label(
                        "Weekly Fuel",
                        systemImage: "fuelpump.fill"
                    )
                }
            }

            // ✅ Archived Weeks
            Section("Archived Weeks") {

                ForEach(archiveFiles, id: \.self) { file in

                    NavigationLink {

                        FuelArchivePrettyView(
                            fileURL: file
                        )

                    } label: {

                        Label(
                            file.deletingPathExtension().lastPathComponent,
                            systemImage: "archivebox.fill"
                        )
                    }
                }
            }
        }
        .navigationTitle("Fuel Archives")
        .onAppear {
            loadArchives()
        }
    }

    func loadArchives() {

        let folder = StorageManager
            .truckReportsFolder()
            .appendingPathComponent("FuelArchive")

        do {

            archiveFiles =
                try FileManager.default
                    .contentsOfDirectory(
                        at: folder,
                        includingPropertiesForKeys: nil
                    )
                    .filter {
                        $0.pathExtension == "json"
                    }
                    .sorted {
                        $0.lastPathComponent > $1.lastPathComponent
                    }

        } catch {

            print(
                "❌ Failed loading fuel archives:",
                error
            )
        }
    }
}

struct FuelArchivePrettyView: View {

    let fileURL: URL

    @State private var entries: [WeeklyFuelEntry] = []

    var totalFuel: Double {
        entries.reduce(0) { $0 + $1.amount }
    }

    var body: some View {

        ScrollView {

            VStack(spacing: 16) {

                // ✅ Summary Card
                VStack(alignment: .leading, spacing: 8) {

                    Text(fileURL.lastPathComponent)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("$\(totalFuel, specifier: "%.2f")")
                        .font(.largeTitle.bold())

                    Text("\(entries.count) fuel entries")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 24))

                // ✅ Entry Cards
                ForEach(entries) { entry in

                    VStack(alignment: .leading, spacing: 10) {

                        HStack {

                            VStack(alignment: .leading, spacing: 4) {

                                Text(entry.driverName)
                                    .font(.headline)

                                Text("Truck \(entry.truckNumber)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text("$\(entry.amount, specifier: "%.2f")")
                                .font(.title3.bold())
                                .foregroundStyle(AppTheme.success)
                        }

                        Text(
                            entry.date.formatted(
                                date: .abbreviated,
                                time: .shortened
                            )
                        )
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                }

                // ✅ Empty State
                if entries.isEmpty {

                    VStack(spacing: 10) {

                        Image(systemName: "fuelpump.slash.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)

                        Text("No fuel entries")
                            .font(.headline)

                        Text("This week has no fuel yet.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                }
            }
            .padding()
        }
        .navigationTitle("Fuel Report")
        .onAppear {
            loadFuelArchive()
        }
    }

    func loadFuelArchive() {

        do {

            let data = try Data(contentsOf: fileURL)

            entries = try JSONDecoder()
                .decode([WeeklyFuelEntry].self, from: data)
                .sorted { $0.date > $1.date }

            print("✅ Loaded fuel archive:", entries.count)

        } catch {

            print("❌ Failed loading fuel archive:", error)
        }
    }
}
