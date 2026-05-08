import SwiftUI
import SwiftData

struct AddFuelView: View {
    let driver: DriverProfile
    
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query var shifts: [Shift]
    @Query var loads: [LoadItem]
    
    @State private var fuelAmount = ""
    
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

                    if activeShift == nil {

                        VStack(spacing: 14) {

                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.largeTitle)
                                .foregroundStyle(.red)

                            Text("No Active Shift")
                                .font(.title2.bold())
                                .foregroundStyle(.white)

                            Text("Start your day before adding fuel.")
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(28)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 30))
                        .padding(.horizontal)

                    } else {

                        VStack(spacing: 22) {

                            VStack(alignment: .leading, spacing: 8) {

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

                        Button {

                            saveFuel()

                        } label: {

                            HStack(spacing: 14) {

                                Image(systemName: "fuelpump.fill")

                                Text("Save Fuel")
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
                    }

                    Spacer(minLength: 40)
                }
                .padding()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }
    
    func saveFuel() {
        guard let shift = activeShift else { return }

        let amount = Double(fuelAmount) ?? 0
        shift.fuelTotal += amount

        do {
            try context.save()
            print("✅ Fuel saved")

            let driverLoads = loads.filter {
                $0.driverName == driver.name
            }

            let currentShift = shift

            _ = CSVExporter.generateCSV(
                loads: driverLoads,
                driver: driver,
                activeShift: currentShift
            )

            dismiss()

        } catch {
            print("❌ Fuel save failed:", error)
        }
    }
}

