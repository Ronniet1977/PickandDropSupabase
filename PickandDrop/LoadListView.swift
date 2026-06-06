import SwiftUI
import SwiftData

struct LoadListView: View {
    let driver: DriverProfile
    
    @Environment(\.modelContext) private var context
    @State private var loads: [SupabaseLoad] = []
    @State private var settings: SupabaseCompanySettings?
    
    var shiftLoads: [SupabaseLoad] {
        loads
            .filter {
                $0.driver_name == driver.name &&
                ($0.is_archived ?? false) == false
            }
            .sorted {
                ($0.created_at ?? "") > ($1.created_at ?? "")
            }
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
                
                VStack(spacing: 24) {
                    
                    // HEADER CARD
                    
                    VStack(alignment: .leading, spacing: 18) {
                        Text(
                            settings?.trucking_company_name
                            ?? "Trucking Company"
                        )
                        .font(.caption.bold())
                        .foregroundStyle(.blue)
                        
                        Text(driver.name)
                            .font(.largeTitle.bold())
                            .foregroundStyle(.white)
                        
                        Text("Truck \(driver.truckNumber)")
                            .foregroundStyle(.white.opacity(0.7))
                        
                        Divider()
                        
                        let pickupTons = shiftLoads.reduce(0.0) {
                            $0 + ($1.pickup_tons ?? 0)
                        }
                        
                        let deliveredTons = shiftLoads.reduce(0.0) {
                            $0 + ($1.delivery_tons ?? 0)
                        }
                        
                        let remainingTons = pickupTons - deliveredTons
                        
                        HStack {
                            
                            loadStat(
                                title: "Loads",
                                value: "\(shiftLoads.count)"
                            )
                            
                            Spacer()
                            
                            loadStat(
                                title: settings?.pickup_company_name ?? "Pickup",
                                value: String(format: "%.0f", pickupTons)
                            )
                            
                            Spacer()
                            
                            loadStat(
                                title: settings?.dropoff_company_name
                                ?? "Dropoff",
                                value: String(format: "%.0f", deliveredTons)
                            )
                            
                            Spacer()
                            
                            loadStat(
                                title: "Remaining",
                                value: String(format: "%.0f", remainingTons)
                            )
                        }
                    }
                    .padding(24)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 30))
                    
                    // EMPTY STATE
                    
                    if shiftLoads.isEmpty {
                        
                        VStack(spacing: 16) {
                            
                            Image(systemName: "shippingbox")
                                .font(.system(size: 54))
                                .foregroundStyle(.gray)
                            
                            Text("No Loads Yet")
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                            
                            Text("Loads added during your shift will appear here.")
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .padding(.top, 80)
                    }
                    
                    // LOAD CARDS
                    
                    ForEach(shiftLoads, id: \.id) { load in
                        
                        VStack(alignment: .leading, spacing: 16) {
                            
                            HStack {
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    
                                    Text(
                                        "\(settings?.pickup_company_name ?? "Pickup") Ticket \(load.pickup_ticket_number ?? "")"
                                    )
                                    .font(.title3.bold())
                                    .foregroundStyle(.white)
                                    
                                    HStack(spacing: 14) {
                                        
                                        Label(
                                            "\(String(format: "%.2f", load.pickup_tons ?? 0)) \(settings?.pickup_company_name ?? "Pickup") Tons",
                                            systemImage: "arrow.up.circle.fill"
                                        )
                                        .foregroundStyle(.blue)
                                        
                                        if load.status == "delivered" {
                                            
                                            Label(
                                                "\(String(format: "%.2f", load.delivery_tons ?? 0)) \(settings?.dropoff_company_name ?? "Dropoff") Tons",
                                                systemImage: "arrow.down.circle.fill"
                                            )
                                            .foregroundStyle(.orange)
                                        }
                                    }
                                    .font(.subheadline.bold())
                                }
                                
                                Spacer()
                                
                                Text(load.status == "delivered" ? "Delivered" : "Picked Up")
                                    .font(.caption.bold())
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        load.status == "delivered"
                                        ? .green.opacity(0.2)
                                        : .orange.opacity(0.2)
                                    )
                                    .foregroundStyle(
                                        load.status == "delivered"
                                        ? .green
                                        : .orange
                                    )
                                    .clipShape(Capsule())
                            }
                            
                            Label(
                                "\(settings?.pickup_company_name ?? "Pickup") → \(settings?.dropoff_company_name ?? "Dropoff")",
                                systemImage: "arrow.left.arrow.right"
                            )
                            .font(.caption.bold())
                            .foregroundStyle(.blue)
                            
                            Divider()
                            
                            VStack(alignment: .leading, spacing: 8) {
                                
                                if let pickedString = load.picked_up_at,
                                   let pickedDate = parseSupabaseDate(pickedString) {

                                    Label(
                                        pickedDate.formatted(
                                            date: .omitted,
                                            time: .shortened
                                        ),
                                        systemImage: "clock.fill"
                                    )
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                                }
                                
                                if load.delivered_at == nil,
                                   let pickedString = load.picked_up_at,
                                   let pickedDate = parseSupabaseDate(pickedString),
                                   !Calendar.current.isDateInToday(pickedDate) {

                                    Label(
                                        "Pending from previous day",
                                        systemImage: "exclamationmark.triangle.fill"
                                    )
                                    .font(.caption.bold())
                                    .foregroundStyle(.yellow)
                                }
                                
                                if let deliveredString = load.delivered_at,
                                   let deliveredDate = parseSupabaseDate(deliveredString) {

                                    Label(
                                        deliveredDate.formatted(
                                            date: .omitted,
                                            time: .shortened
                                        ),
                                        systemImage: "checkmark.circle.fill"
                                    )
                                    .font(.caption)
                                    .foregroundStyle(.green)
                                }
                                
                                if let pickedString = load.picked_up_at,
                                   let deliveredString = load.delivered_at,
                                   let pickedDate = parseSupabaseDate(pickedString),
                                   let deliveredDate = parseSupabaseDate(deliveredString) {

                                    let duration = deliveredDate.timeIntervalSince(pickedDate)

                                    let hours = Int(duration) / 3600
                                    let minutes = (Int(duration) % 3600) / 60

                                    Text("Duration: \(hours)h \(minutes)m")
                                        .font(.caption.bold())
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                        .padding(22)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 28))
                        .overlay(
                            RoundedRectangle(cornerRadius: 28)
                                .stroke(.white.opacity(0.08))
                        )
                        //.contextMenu {
                        
                        //Button(role: .destructive) {
                        
                        //context.delete(load)
                        //try? context.save()
                        
                        //} label: {
                        
                        //Label(
                        //"Delete Load",
                        //systemImage: "trash"
                        //)
                        //}
                    }
                }
            }
            .padding()
        }
        .navigationTitle(
            "\(settings?.pickup_company_name ?? "Pickup") Loads"
        )
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .onAppear {
            Task {
                let loadedLoads =
                await LoadSupabaseManager.shared.fetchLoads()
                
                let loadedSettings =
                await CompanySupabaseManager.shared.fetchCompanySettings()
                
                await MainActor.run {
                    loads = loadedLoads
                    settings = loadedSettings
                }
            }
        }
    }
    
    func parseSupabaseDate(_ value: String) -> Date? {

        let iso = ISO8601DateFormatter()
        if let date = iso.date(from: value) {
            return date
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ssXXXXX"

        if let date = formatter.date(from: value) {
            return date
        }

        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSSSSXXXXX"

        return formatter.date(from: value)
    }
    
    func loadStat(
        title: String,
        value: String
    ) -> some View {

        VStack(alignment: .leading, spacing: 4) {

            Text(title)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))

            Text(value)
                .font(.title.bold())
                .foregroundStyle(.white)
        }
    }
}

    
    
