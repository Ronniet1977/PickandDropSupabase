import SwiftUI
import SwiftData

struct StartShiftView: View {
    
    let driver: DriverProfile
    
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query var shifts: [Shift]
    
    @State private var settings: SupabaseCompanySettings?
    
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

            VStack(spacing: 32) {

                Spacer()

                VStack(spacing: 24) {

                    HStack(spacing: 10) {

                        Circle()
                            .fill(activeShift == nil ? .green : .orange)
                            .frame(width: 12, height: 12)

                        Text(activeShift == nil ? "READY TO START" : "SHIFT ACTIVE")
                            .font(.caption.weight(.bold))
                            .tracking(1.2)
                    }
                    .foregroundStyle(.white.opacity(0.85))

                    ZStack {

                        Circle()
                            .fill(.green.opacity(0.12))
                            .frame(width: 140, height: 140)

                        Circle()
                            .stroke(.green.opacity(0.25), lineWidth: 2)
                            .frame(width: 150, height: 150)

                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 72))
                            .foregroundStyle(.green)
                            .shadow(color: .green.opacity(0.5), radius: 20)
                    }

                    Text("Start Day")
                        .font(.system(size: 42, weight: .bold))

                    VStack(spacing: 6) {

                        Text(driver.name)
                            .font(.title2.weight(.semibold))

                        Text("Truck \(driver.truckNumber)")
                            .foregroundStyle(.white.opacity(0.7))
                        
                        Text(
                            settings?.trucking_company_name
                            ?? "Trucking Company"
                        )
                        .font(.caption.bold())
                        .foregroundStyle(.blue)

                        Text(
                            "\(settings?.pickup_company_name ?? "Pickup") → \(settings?.dropoff_company_name ?? "Dropoff")"
                        )
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))

                        Text(Date(), style: .time)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.blue.opacity(0.9))
                    }
                }
                .foregroundStyle(.white)

                VStack(spacing: 20) {

                    if let shift = activeShift {

                        VStack(spacing: 14) {

                            Label(
                                "Shift Already Active",
                                systemImage: "checkmark.circle.fill"
                            )
                            .font(.headline)
                            .foregroundStyle(.green)

                            Text(
                                "Started \(shift.startedAt.formatted(date: .abbreviated, time: .shortened))"
                            )
                            .foregroundStyle(.white.opacity(0.7))

                            TimelineView(.periodic(from: .now, by: 1)) { context in

                                let elapsed = context.date.timeIntervalSince(shift.startedAt)

                                let hours = Int(elapsed) / 3600
                                let minutes = (Int(elapsed) % 3600) / 60
                                let seconds = Int(elapsed) % 60

                                Text(
                                    String(
                                        format: "%02d:%02d:%02d",
                                        hours,
                                        minutes,
                                        seconds
                                    )
                                )
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(.green)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(28)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 30))

                    } else {

                        Button {

                            startShift()

                        } label: {

                            HStack(spacing: 14) {

                                Image(systemName: "play.fill")

                                Text("Start Day")
                                    .fontWeight(.bold)
                            }
                            .font(.title3)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.green.gradient)
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                            .shadow(color: .green.opacity(0.4), radius: 14)
                        }
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarTitleDisplayMode(.inline)
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
    
    func startShift() {
        let newShift = Shift()
        newShift.driverName = driver.name
        newShift.companyName =
            settings?.trucking_company_name ?? ""

        context.insert(newShift)

        do {
            try context.save()
            print("✅ Shift started")
            Task {

                await DriverSupabaseManager.shared
                    .updateDutyStatus(
                        username: driver.username,
                        dutyStatus: "active"
                    )
            }

            dismiss()

        } catch {
            print("❌ Failed to start shift:", error)
        }
    }
}
