import SwiftUI

struct AppUpdateAdminView: View {
    
    @State private var forceUpdate = false
    
    @State private var minimumBuild = ""
    @State private var latestBuild = ""
    
    @State private var updateURL = ""
    
    @State private var isLoading = true
    @State private var isSaving = false
    
    @State private var showSaved = false
    @State private var errorText = ""
    @State private var showError = false
    
    @State private var minimumVersion = ""
    @State private var latestVersion = ""
    
    var body: some View {
        
        Form {
            
            Section("Update Gate") {
                
                Toggle(
                    "Force Update",
                    isOn: $forceUpdate
                )
                
                TextField(
                    "Minimum Version",
                    text: $minimumVersion
                )

                TextField(
                    "Latest Version",
                    text: $latestVersion
                )
                
                TextField(
                    "Minimum Build",
                    text: $minimumBuild
                )
                .keyboardType(.numberPad)
                
                TextField(
                    "Latest Build",
                    text: $latestBuild
                )
                .keyboardType(.numberPad)
            }
            
            Section("Update Link") {
                
                TextField(
                    "TestFlight / App Store URL",
                    text: $updateURL
                )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            }
            
            Section {
                
                HStack {
                    
                    Text("Installed Build")
                    
                    Spacer()
                    
                    Text(currentBuild)
                        .foregroundStyle(.secondary)
                }
            }
            
            Section {
                
                Button {
                    
                    Task {
                        await save()
                    }
                    
                } label: {
                    
                    HStack {
                        
                        Spacer()
                        
                        if isSaving {
                            
                            ProgressView()
                            
                        } else {
                            
                            Label(
                                "Save Update Settings",
                                systemImage:
                                    "checkmark.circle.fill"
                            )
                        }
                        
                        Spacer()
                    }
                }
                .disabled(
                    isSaving ||
                    minimumBuild.isEmpty ||
                    latestBuild.isEmpty
                )
            }
        }
        .navigationTitle("App Update Control")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            
            if isLoading {
                
                ProgressView(
                    "Loading settings..."
                )
            }
        }
        .task {
            await load()
        }
        .alert(
            "Update Settings Saved",
            isPresented: $showSaved
        ) {
            Button("OK") { }
        }
        .alert(
            "Unable to Save",
            isPresented: $showError
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorText)
        }
    }
    
    private var currentBuild: String {
        
        Bundle.main.object(
            forInfoDictionaryKey:
                "CFBundleVersion"
        ) as? String ?? "Unknown"
    }
    
    @MainActor
    private func load() async {
        
        isLoading = true
        
        defer {
            isLoading = false
        }
        
        guard let config =
                await AppUpdateManager.shared
            .fetchConfig()
        else {
            
            errorText =
            "Unable to load app update settings."
            
            showError = true
            
            return
        }
        
        forceUpdate =
        config.force_update
        
        minimumVersion =
            config.minimum_version

        latestVersion =
            config.latest_version
        
        minimumBuild =
        String(
            config.minimum_build
        )
        
        latestBuild =
        String(
            config.latest_build
        )
        
        updateURL =
        config.app_store_url ?? ""
    }
    
    @MainActor
    private func save() async {
        
        guard
            let minBuild =
                Int(minimumBuild),
            
                let latest =
                Int(latestBuild)
        else {
            
            errorText =
            "Enter valid build numbers."
            
            showError = true
            
            return
        }
        
        isSaving = true
        
        let success =
            await AppUpdateManager.shared
                .updateConfig(
                    forceUpdate: forceUpdate,
                    minimumVersion: minimumVersion,
                    latestVersion: latestVersion,
                    minimumBuild: minBuild,
                    latestBuild: latest,
                    appStoreURL: updateURL
                )
        
        isSaving = false
        
        if success {
            
            showSaved = true
            
        } else {
            
            errorText =
            "The update settings could not be saved."
            
            showError = true
        }
    }
}

