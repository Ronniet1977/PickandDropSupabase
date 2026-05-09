import SwiftUI
import SwiftData

struct SetupView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query var drivers: [DriverProfile]
    
    @AppStorage("hasSetup") private var hasSetup = false
    @AppStorage("currentDriverName") var currentDriverName: String = ""
    
    @State private var driverName = ""
    @State private var truckNumber = ""
    @State private var role = "driver"
    
    var body: some View {
        
        ZStack {
            
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.09, blue: 0.16),
                    Color(red: 0.10, green: 0.18, blue: 0.32),
                    .black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                
                VStack(spacing: 36) {
                    
                    Spacer(minLength: 40)
                    
                    // LOGO / HEADER
                    
                    VStack(spacing: 18) {
                        
                        ZStack {
                            
                            Circle()
                                .fill(.blue.opacity(0.15))
                                .frame(width: 120, height: 120)
                            
                            Image(systemName: "truck.box.fill")
                                .font(.system(size: 56))
                                .foregroundStyle(.blue)
                        }
                        
                        Text("Pick & Drop")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundStyle(.white)
                        
                        Text("Fleet Operations")
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    
                    // FORM CARD
                    
                    VStack(spacing: 24) {
                        
                        VStack(alignment: .leading, spacing: 10) {
                            
                            Text("Driver Name")
                                .font(.caption.bold())
                                .foregroundStyle(.white.opacity(0.7))
                            
                            TextField("", text: $driverName)
                                .padding()
                                .background(.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 18))
                                .foregroundStyle(.white)
                        }
                        
                        VStack(alignment: .leading, spacing: 10) {
                            
                            Text("Truck Number")
                                .font(.caption.bold())
                                .foregroundStyle(.white.opacity(0.7))
                            
                            TextField("", text: $truckNumber)
                                .padding()
                                .background(.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 18))
                                .foregroundStyle(.white)
                        }
                        
                        VStack(alignment: .leading, spacing: 12) {
                            
                            Text("Role")
                                .font(.caption.bold())
                                .foregroundStyle(.white.opacity(0.7))
                            
                            Picker("Role", selection: $role) {
                                
                                Text("Driver")
                                    .tag("driver")
                                
                                Text("Admin")
                                    .tag("admin")
                            }
                            .pickerStyle(.segmented)
                        }
                        
                        Button {
                            
                            let driver = DriverProfile()
                            driver.name = driverName
                            driver.truckNumber = truckNumber
                            
                            driver.username = driverName.lowercased()
                            driver.password = "1234"
                            
                            driver.role = role
                            
                            currentDriverName = driver.name
                            context.insert(driver)
                            
                            do {
                                
                                try context.save()
                                
                                print("✅ SAVE SUCCESS")
                                
                                hasSetup = true
                                
                            } catch {
                                
                                print(
                                    "❌ SAVE FAILED:",
                                    error.localizedDescription
                                )
                            }
                            
                        } label: {
                            
                            HStack {
                                
                                Image(systemName: "arrow.right.circle.fill")
                                
                                Text("Login")
                                    .fontWeight(.bold)
                            }
                            .font(.title3)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.blue.gradient)
                            .clipShape(RoundedRectangle(cornerRadius: 22))
                        }
                        .padding(.top, 10)
                    }
                    .padding(28)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 34))
                    .overlay(
                        RoundedRectangle(cornerRadius: 34)
                            .stroke(.white.opacity(0.08))
                    )
                    
                    Spacer(minLength: 50)
                }
                .padding()
            }
        }
    }
}

