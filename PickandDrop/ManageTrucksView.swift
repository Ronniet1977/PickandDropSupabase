//
//  ManageTrucksView.swift
//  PickandDrop
//
//  Created by Ronald Thayer Jr on 9/16/26.
//

import SwiftUI

struct ManageTrucksView: View {

    @State private var trucks: [SupabaseTruck] = []

    @State private var isLoading = true

    @State private var showingAddTruck = false
    @State private var newTruckNumber = ""

    @State private var truckToEdit: SupabaseTruck?
    @State private var editedTruckNumber = ""

    var body: some View {

        List {

            if isLoading {

                HStack {
                    Spacer()
                    ProgressView("Loading Trucks...")
                    Spacer()
                }

            } else if trucks.isEmpty {

                ContentUnavailableView(
                    "No Trucks",
                    systemImage: "truck.box",
                    description:
                        Text("Add your first truck.")
                )

            } else {

                Section("Active Trucks") {

                    ForEach(
                        trucks.filter { $0.is_active }
                    ) { truck in

                        truckRow(truck)
                    }
                }

                let inactive =
                    trucks.filter { !$0.is_active }

                if !inactive.isEmpty {

                    Section("Inactive Trucks") {

                        ForEach(inactive) { truck in

                            inactiveTruckRow(truck)
                        }
                    }
                }
            }
        }
        .navigationTitle("Manage Trucks")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {

            ToolbarItem(
                placement: .topBarTrailing
            ) {

                Button {
                    newTruckNumber = ""
                    showingAddTruck = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .task {
            await loadTrucks()
        }

        // MARK: Add Truck

        .alert(
            "Add Truck",
            isPresented: $showingAddTruck
        ) {

            TextField(
                "Truck Number",
                text: $newTruckNumber
            )
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled()

            Button("Add") {

                Task {
                    await addTruck()
                }
            }

            Button(
                "Cancel",
                role: .cancel
            ) {}

        } message: {

            Text(
                "Enter the truck number you want available to drivers."
            )
        }

        // MARK: Edit Truck

        .alert(
            "Edit Truck",
            isPresented: Binding(
                get: {
                    truckToEdit != nil
                },
                set: { showing in

                    if !showing {
                        truckToEdit = nil
                    }
                }
            )
        ) {

            TextField(
                "Truck Number",
                text: $editedTruckNumber
            )
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled()

            Button("Save") {

                if let truck = truckToEdit {

                    Task {
                        await updateTruck(truck)
                    }
                }
            }

            Button(
                "Cancel",
                role: .cancel
            ) {}

        } message: {

            Text(
                "This changes the truck number for future selections. Historical records are not changed."
            )
        }
    }

    // MARK: - Active Truck Row

    @ViewBuilder
    private func truckRow(
        _ truck: SupabaseTruck
    ) -> some View {

        HStack {

            Label(
                "Truck \(truck.truck_number)",
                systemImage: "truck.box.fill"
            )

            Spacer()

            Menu {

                Button {

                    editedTruckNumber =
                        truck.truck_number

                    truckToEdit = truck

                } label: {

                    Label(
                        "Edit",
                        systemImage: "pencil"
                    )
                }

                Button(
                    role: .destructive
                ) {

                    Task {

                        let success =
                            await TruckSupabaseManager.shared
                                .setTruckActive(
                                    id: truck.id,
                                    isActive: false
                                )

                        if success {
                            await loadTrucks()
                        }
                    }

                } label: {

                    Label(
                        "Deactivate",
                        systemImage: "archivebox"
                    )
                }

            } label: {

                Image(
                    systemName: "ellipsis.circle"
                )
                .font(.title3)
            }
        }
    }

    // MARK: - Inactive Truck Row

    @ViewBuilder
    private func inactiveTruckRow(
        _ truck: SupabaseTruck
    ) -> some View {

        HStack {

            Label(
                "Truck \(truck.truck_number)",
                systemImage: "truck.box"
            )
            .foregroundStyle(.secondary)

            Spacer()

            Button("Reactivate") {

                Task {

                    let success =
                        await TruckSupabaseManager.shared
                            .setTruckActive(
                                id: truck.id,
                                isActive: true
                            )

                    if success {
                        await loadTrucks()
                    }
                }
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Load

    private func loadTrucks() async {

        let loaded =
            await TruckSupabaseManager.shared
                .fetchAllTrucks()

        await MainActor.run {
            trucks = loaded
            isLoading = false
        }
    }

    // MARK: - Add

    private func addTruck() async {

        let cleanNumber =
            newTruckNumber
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

        guard !cleanNumber.isEmpty else {
            return
        }

        let success =
            await TruckSupabaseManager.shared
                .addTruck(
                    truckNumber: cleanNumber
                )

        if success {

            await MainActor.run {
                newTruckNumber = ""
            }

            await loadTrucks()
        }
    }

    // MARK: - Update

    private func updateTruck(
        _ truck: SupabaseTruck
    ) async {

        let cleanNumber =
            editedTruckNumber
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

        guard !cleanNumber.isEmpty else {
            return
        }

        let success =
            await TruckSupabaseManager.shared
                .updateTruck(
                    id: truck.id,
                    truckNumber: cleanNumber
                )

        if success {

            await MainActor.run {
                truckToEdit = nil
                editedTruckNumber = ""
            }

            await loadTrucks()
        }
    }
}
