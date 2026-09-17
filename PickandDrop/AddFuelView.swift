import SwiftUI
import SwiftData

struct AddFuelView: View {
    let driver: DriverProfile
    
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query var shifts: [Shift]
    @Query var loads: [LoadItem]
    @Query var companySettings: [CompanySettings]
    
    @StateObject private var notificationManager = NotificationSyncManager()
    
    @State private var fuelAmount = ""
    
    @State private var showCamera = false
    @State private var receiptImage: UIImage?
    
    @State private var trucks: [SupabaseTruck] = []
    @State private var selectedTruckNumber = ""
    @State private var isSavingFuel = false
    
    var settings: CompanySettings? {
        companySettings.first
    }
    
    var activeShift: Shift? {
        shifts.first(where: {
            $0.driverName == driver.name && $0.status == "active"
        })
    }
    
    var body: some View {

        ZStack {

            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.11, blue: 0.18),
                    Color(red: 0.15, green: 0.22, blue: 0.35),
                    Color.black.opacity(0.95)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {

                VStack(spacing: 30) {

                    Spacer(minLength: 20)

                    VStack(spacing: 18) {

                        ZStack {

                            Circle()
                                .fill(.orange.opacity(0.15))
                                .frame(width: 120, height: 120)

                            Image(systemName: "fuelpump.fill")
                                .font(.system(size: 58))
                                .foregroundStyle(.orange)
                        }

                        Text("Add Fuel")
                            .font(.system(size: 38, weight: .bold))
                            .foregroundStyle(.white)

                        Text(driver.name)
                            .foregroundStyle(.white.opacity(0.7))

                        Text("Truck \(driver.truckNumber)")
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    
                        VStack(spacing: 22) {

                            VStack(alignment: .leading, spacing: 8) {
                                VStack(alignment: .leading, spacing: 8) {

                                    Text("Truck Number")
                                        .font(.caption.bold())
                                        .foregroundStyle(.white.opacity(0.7))

                                    Picker(
                                        "Truck Number",
                                        selection: $selectedTruckNumber
                                    ) {

                                        Text("Select Truck")
                                            .tag("")

                                        ForEach(
                                            truckNumbers,
                                            id: \.self
                                        ) { truck in

                                            Text("Truck \(truck)")
                                                .tag(truck)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .tint(.white)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding()
                                    .background(.white.opacity(0.08))
                                    .clipShape(
                                        RoundedRectangle(cornerRadius: 18)
                                    )
                                }

                                Text("Fuel Amount")
                                    .font(.caption.bold())
                                    .foregroundStyle(.white.opacity(0.7))

                                TextField(
                                    "Enter Fuel Total",
                                    text: $fuelAmount
                                )
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.plain)
                                .padding()
                                .background(.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 18))
                                .foregroundStyle(.white)
                            }

                            if !fuelAmount.isEmpty &&
                                Double(fuelAmount) == nil {

                                HStack {

                                    Image(systemName: "exclamationmark.circle.fill")

                                    Text("Enter a valid fuel amount")
                                }
                                .font(.caption.bold())
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(26)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 30))
                        .padding(.horizontal)
                        
                        VStack(spacing: 16) {
                            
                            Button {
                                
                                showCamera = true
                                
                            } label: {
                                
                                HStack(spacing: 12) {
                                    
                                    Image(systemName: "camera.fill")
                                    
                                    Text(
                                        receiptImage == nil
                                        ? "Take Fuel Receipt"
                                        : "Receipt Added"
                                    )
                                    .fontWeight(.bold)
                                }
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    receiptImage == nil
                                    ? Color.blue
                                    : Color.green
                                )
                                .clipShape(
                                    RoundedRectangle(cornerRadius: 22)
                                )
                            }
                        }

                    Button {

                        guard !isSavingFuel else {
                            return
                        }

                        isSavingFuel = true
                        saveFuel()

                    } label: {

                            HStack(spacing: 14) {

                                Image(systemName: "fuelpump.fill")

                                Text(
                                    isSavingFuel
                                    ? "Saving Fuel..."
                                    : "Save Fuel"
                                )
                                .fontWeight(.bold)
                            }
                            .font(.title3)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.orange.gradient)
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                            .shadow(color: .orange.opacity(0.4), radius: 14)
                        }
                        .padding(.horizontal)
                        .disabled(
                            isSavingFuel ||
                            selectedTruckNumber.isEmpty ||
                            (Double(fuelAmount) ?? 0) <= 0
                        )

                    Spacer(minLength: 40)
                }
                .padding()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .onAppear {
            Task {

                let loadedTrucks =
                    await TruckSupabaseManager.shared
                        .fetchActiveTrucks()

                await MainActor.run {

                    trucks = loadedTrucks

                    // Use the driver's assigned truck
                    // only if it exists in the active truck list.
                    if selectedTruckNumber.isEmpty {

                        if loadedTrucks.contains(
                            where: {
                                $0.truck_number ==
                                driver.truckNumber
                            }
                        ) {
                            selectedTruckNumber =
                                driver.truckNumber
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showCamera) {

            CameraPicker(
                image: $receiptImage
            )
        }
    }
    
    func sendAdminNotification(
        type: String,
        message: String,
        ticket: String? = nil
    ) {
        let note = AppNotification(
            type: type,
            driverName: driver.name,
            truckNumber: selectedTruckNumber,
            message: message,
            loadTicket: ticket
        )

        notificationManager.sendNotification(note)
    }
    
    func saveFuel() {

        guard
            let amountValue = Double(fuelAmount),
            amountValue > 0
        else {
            isSavingFuel = false
            return
        }

        let amount = amountValue

        Task {

            defer {
                Task { @MainActor in
                    isSavingFuel = false
                }
            }

            var receiptPath: String?

            if let receiptImage {

                receiptPath =
                    await FuelReceiptStorageManager.shared
                        .uploadReceipt(
                            image: receiptImage,
                            driverName: driver.name
                        )
            }

            let saved =
                await FuelSupabaseManager.shared.addFuel(
                    driverName: driver.name,
                    truckNumber: selectedTruckNumber,
                    amount: amountValue,
                    receiptPath: receiptPath
                )

            guard saved else {

                print("❌ Fuel was not saved — keeping screen open")

                return
            }

            // Only update shift after Supabase succeeds.
            if let shift = activeShift {

                shift.fuelTotal += amount

                do {
                    try context.save()
                    print("✅ Shift fuel total updated")
                } catch {
                    print("❌ Shift fuel total save failed:", error)
                }
            }

            sendAdminNotification(
                type: "Fuel Added",
                message:
                    "\(driver.name) added fuel to Truck \(selectedTruckNumber) • $\(String(format: "%.2f", amountValue))"
            )

            await MainActor.run {
                fuelAmount = ""
                receiptImage = nil
                dismiss()
            }
        }
    }
    
    private var truckNumbers: [String] {

        trucks
            .filter { $0.is_active }
            .map { $0.truck_number }
            .sorted()
    }
}

