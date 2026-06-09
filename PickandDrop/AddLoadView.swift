import SwiftUI
import SwiftData

struct AddLoadView: View {
    let driver: DriverProfile
    
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    @Query var shifts: [Shift]
    
    @StateObject private var notificationManager = NotificationSyncManager()
    @State private var settings: SupabaseCompanySettings?

    @State private var pickupTicket = ""
    @State private var pickupTons = ""
    
    
    var activeShift: Shift? {
        shifts.first(where: {
            $0.driverName == driver.name &&
            $0.status.lowercased() == "active"
        })
    }
    
    var isValidLoad: Bool {
        Double(pickupTons) != nil
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

                VStack(spacing: 28) {

                    Spacer(minLength: 20)

                    VStack(spacing: 18) {

                        ZStack {

                            Circle()
                                .fill(.blue.opacity(0.15))
                                .frame(width: 120, height: 120)

                            Image(systemName: "shippingbox.fill")
                                .font(.system(size: 58))
                                .foregroundStyle(.blue)
                        }

                        Text("Add Load")
                            .font(.system(size: 38, weight: .bold))
                            .foregroundStyle(.white)
                        
                        Text(
                            "\(settings?.pickup_company_name ?? "Pickup") → \(settings?.trucking_company_name ?? "Dropoff")"
                        )
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.blue.opacity(0.15))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())

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

                            Text("Start your day before adding loads.")
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

                                Text("\(settings?.pickup_company_name ?? "Pickup") Ticket Number (Optional)")
                                    .font(.caption.bold())
                                    .foregroundStyle(.white.opacity(0.7))

                                TextField(
                                    "Optional - enter later",
                                    text: $pickupTicket
                                )
                                .textFieldStyle(.plain)
                                .padding()
                                .background(.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 18))
                                .foregroundStyle(.white)
                            }

                            VStack(alignment: .leading, spacing: 8) {

                                Text(
                                    "\(settings?.pickup_company_name ?? "Pickup") Tons"
                                )
                                    .font(.caption.bold())
                                    .foregroundStyle(.white.opacity(0.7))

                                TextField(
                                    "Enter Tons",
                                    text: $pickupTons
                                )
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.plain)
                                .padding()
                                .background(.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 18))
                                .foregroundStyle(.white)
                            }

                            if !pickupTons.isEmpty &&
                                Double(pickupTons) == nil {

                                HStack {

                                    Image(systemName: "exclamationmark.circle.fill")

                                    Text("Enter a valid number for tons")
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
                            Task {
                                await saveLoad()
                            }
                        } label: {

                            HStack(spacing: 14) {

                                Image(systemName: "plus.circle.fill")

                                Text("Save Load")
                                    .fontWeight(.bold)
                            }
                            .font(.title3)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.blue.gradient)
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                            .shadow(color: .blue.opacity(0.4), radius: 14)
                        }
                        .padding(.horizontal)
                        .disabled(!isValidLoad || activeShift == nil)
                    }

                    Spacer(minLength: 40)
                }
                .padding()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .onAppear {
            Task {
                let loadedSettings =
                    await CompanySupabaseManager
                        .shared
                        .fetchCompanySettings()

                await MainActor.run {
                    settings = loadedSettings
                }
            }
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
            truckNumber: driver.truckNumber,
            message: message,
            loadTicket: ticket
        )

        notificationManager.sendNotification(note)
    }
    
    func saveLoad() async {
        guard let tonsValue = Double(pickupTons) else { return }
        
        let cleanTicket =
        pickupTicket.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let displayTicket =
        cleanTicket.isEmpty ? "No pickup ticket yet" : cleanTicket
        
        // ✅ Save load to Supabase
        await LoadSupabaseManager.shared.addLoad(
            driverName: driver.name,
            truckNumber: driver.truckNumber,
            pickupTicketNumber: cleanTicket,
            pickupTons: tonsValue
        )
        
        // ✅ Send admin notification to Supabase
        sendAdminNotification(
            type: "Load Added",
            message: "\(driver.name) picked up \(displayTicket) • \(tonsValue) tons",
            ticket: cleanTicket
        )
        
        await MainActor.run {
            pickupTicket = ""
            pickupTons = ""
            dismiss()
        }
    }
}
