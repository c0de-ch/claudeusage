import SwiftUI

struct SettingsView: View {
    @Bindable var appState: AppState
    @State private var launchAtLogin = false

    private let intervals: [(String, TimeInterval)] = [
        ("30 seconds", 30),
        ("1 minute", 60),
        ("2 minutes", 120),
        ("5 minutes", 300),
        ("10 minutes", 600),
    ]

    var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            displayTab
                .tabItem {
                    Label("Display", systemImage: "eye")
                }

            advancedTab
                .tabItem {
                    Label("Advanced", systemImage: "wrench")
                }
        }
        .frame(width: 380, height: 320)
        .onAppear {
            if #available(macOS 13.0, *) {
                launchAtLogin = LaunchAtLogin.isEnabled
            }
        }
    }

    // MARK: - General Tab

    private var generalTab: some View {
        Form {
            Picker("Refresh interval", selection: $appState.refreshInterval) {
                ForEach(intervals, id: \.1) { label, value in
                    Text(label).tag(value)
                }
            }

            Toggle("Launch at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, newValue in
                    if #available(macOS 13.0, *) {
                        try? LaunchAtLogin.setEnabled(newValue)
                    }
                }

            Section("Notifications") {
                Toggle("Notify at 75% usage", isOn: $appState.notifyAt75)
                Toggle("Notify at 90% usage", isOn: $appState.notifyAt90)
            }

            Section("Credentials") {
                LabeledContent("Status") {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(credentialStatusColor)
                            .frame(width: 8, height: 8)
                        Text(appState.credentialManager.credentialStatus.description)
                            .font(.caption)
                    }
                }

                Button("Reload Credentials") {
                    Task {
                        try? await appState.credentialManager.loadCredentials()
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Display Tab

    private var displayTab: some View {
        Form {
            Section("Show in menu bar") {
                Toggle("5-Hour window", isOn: $appState.showFiveHour)
                Toggle("7-Day window", isOn: $appState.showSevenDay)
                Toggle("Opus usage", isOn: $appState.showOpus)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Advanced Tab

    private var advancedTab: some View {
        Form {
            Section(header: Text("Fallback: Web API (Cookie Auth)"),
                    footer: Text("Only needed if OAuth endpoint has issues. Get the session cookie from claude.ai browser DevTools.")) {
                TextField("Organization ID", text: $appState.organizationId)
                    .textFieldStyle(.roundedBorder)
                SecureField("Session Cookie", text: $appState.sessionCookie)
                    .textFieldStyle(.roundedBorder)
            }

            Section("About") {
                LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                LabeledContent("Build", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
            }
        }
        .formStyle(.grouped)
    }

    private var credentialStatusColor: Color {
        switch appState.credentialManager.credentialStatus {
        case .loaded: return .green
        case .refreshing: return .yellow
        case .error, .expired: return .red
        case .unknown: return .gray
        }
    }
}
