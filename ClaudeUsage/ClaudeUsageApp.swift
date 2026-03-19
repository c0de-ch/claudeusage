import SwiftUI

@main
struct ClaudeUsageApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            UsagePopoverView(appState: appState)
        } label: {
            MenuBarLabel(appState: appState)
                .task {
                    appState.startIfNeeded()
                }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(appState: appState)
        }
    }
}

struct MenuBarLabel: View {
    let appState: AppState

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "brain")
                .symbolRenderingMode(.hierarchical)
            Text(appState.menuBarText)
                .font(.system(.caption, design: .monospaced))
                .monospacedDigit()
        }
        .foregroundStyle(appState.menuBarColor)
    }
}
