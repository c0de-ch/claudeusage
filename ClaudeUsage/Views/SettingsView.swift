import SwiftUI

struct SettingsView: View {
    @Bindable var appState: AppState
    @State private var launchAtLogin = false
    @State private var showingCookieAuth = false

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
            Section(header: Text("Show in menu bar"),
                    footer: Text("With one item selected, the menu bar shows just the percentage (e.g. \"24%\"). With multiple, it shows prefixed values (e.g. \"5h:45% 7d:24%\").")) {
                Toggle("5-Hour window", isOn: $appState.showFiveHour)
                Toggle("7-Day window", isOn: $appState.showSevenDay)
                Toggle("Opus usage", isOn: $appState.showOpus)
            }

            Section("Preview") {
                HStack {
                    Image(systemName: "brain")
                        .foregroundStyle(.secondary)
                    Text(appState.menuBarText)
                        .font(.system(.body, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(appState.menuBarColor)
                }
                .padding(.vertical, 2)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Advanced Tab

    private var advancedTab: some View {
        Form {
            Section(header: Text("Fallback: Web API (Cookie Auth)"),
                    footer: Text("Only needed if OAuth endpoint has issues.")) {

                if appState.sessionCookie.isEmpty {
                    Button("Sign in to claude.ai...") {
                        showingCookieAuth = true
                    }
                } else {
                    LabeledContent("Session") {
                        HStack(spacing: 4) {
                            Circle().fill(.green).frame(width: 8, height: 8)
                            Text("Authenticated")
                                .font(.caption)
                        }
                    }
                    LabeledContent("Org ID") {
                        Text(appState.organizationId.isEmpty ? "—" : appState.organizationId)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Button("Sign in again...") {
                        showingCookieAuth = true
                    }
                    Button("Clear", role: .destructive) {
                        appState.sessionCookie = ""
                        appState.organizationId = ""
                    }
                }
            }

            Section("About") {
                LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                LabeledContent("Build", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
            }
        }
        .formStyle(.grouped)
        .sheet(isPresented: $showingCookieAuth) {
            CookieAuthView(
                onComplete: { cookie, orgId in
                    appState.sessionCookie = cookie
                    appState.organizationId = orgId
                    showingCookieAuth = false
                },
                onCancel: {
                    showingCookieAuth = false
                }
            )
        }
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
