import SwiftUI

struct AdminLocationsView: View {
    
    @State private var locations: [SupabaseLocation] = []
    
    @State private var locationName = ""
    @State private var locationType = "dropoff"
    
    @State private var isSaving = false
    
    var body: some View {
        
        List {
            
            Section("Add Location") {
                
                TextField(
                    "Location Name",
                    text: $locationName
                )
                
                Picker(
                    "Type",
                    selection: $locationType
                ) {
                    
                    Text("Pickup")
                        .tag("pickup")
                    
                    Text("Dropoff")
                        .tag("dropoff")
                    
                    Text("Both")
                        .tag("both")
                }
                
                Button {
                    
                    Task {
                        await addLocation()
                    }
                    
                } label: {
                    
                    HStack {
                        
                        Spacer()
                        
                        if isSaving {
                            
                            ProgressView()
                            
                        } else {
                            
                            Label(
                                "Add Location",
                                systemImage:
                                    "plus.circle.fill"
                            )
                        }
                        
                        Spacer()
                    }
                }
                .disabled(
                    locationName
                        .trimmingCharacters(
                            in: .whitespacesAndNewlines
                        )
                        .isEmpty ||
                    isSaving
                )
            }
            
            Section("Active Locations") {
                
                if locations.isEmpty {
                    
                    Text("No locations")
                        .foregroundStyle(.secondary)
                    
                } else {
                    
                    ForEach(locations) { location in
                        
                        HStack {
                            
                            VStack(alignment: .leading) {
                                
                                Text(location.name)
                                
                                Text(
                                    location.location_type
                                        .capitalized
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            Button(
                                role: .destructive
                            ) {
                                
                                Task {
                                    await deactivate(
                                        location
                                    )
                                }
                                
                            } label: {
                                
                                Image(
                                    systemName:
                                        "trash"
                                )
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Locations")
        .task {
            await loadLocations()
        }
        .refreshable {
            await loadLocations()
        }
    }
    
    @MainActor
    private func loadLocations() async {
        
        locations =
        await LocationSupabaseManager.shared
            .fetchLocations()
    }
    
    @MainActor
    private func addLocation() async {
        
        guard !isSaving else {
            return
        }
        
        isSaving = true
        
        let success =
        await LocationSupabaseManager.shared
            .addLocation(
                name: locationName,
                locationType: locationType
            )
        
        if success {
            
            locationName = ""
            
            locations =
            await LocationSupabaseManager.shared
                .fetchLocations()
        }
        
        isSaving = false
    }
    
    @MainActor
    private func deactivate(
        _ location: SupabaseLocation
    ) async {
        
        let success =
        await LocationSupabaseManager.shared
            .deactivateLocation(
                id: location.id
            )
        
        if success {
            
            locations =
            await LocationSupabaseManager.shared
                .fetchLocations()
        }
    }
}

