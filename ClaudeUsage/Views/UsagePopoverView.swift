import AppKit
import SwiftUI

struct UsagePopoverView: View {
    let appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Claude Usage")
                    .font(.headline)
                Spacer()
                if appState.isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Button(action: { appState.manualRefresh() }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                    .help("Refresh now")
                }
            }

            if let lastUpdated = appState.lastUpdated {
                Text("Updated \(TimeFormatting.lastUpdated(lastUpdated))")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Divider()

            // Error banner
            if let error = appState.error {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.yellow.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            // Usage cards
            if let usage = appState.usage {
                if appState.showFiveHour, let fiveHour = usage.fiveHour {
                    UsageCardView(title: "5-Hour Window", window: fiveHour)
                }

                if appState.showSevenDay, let sevenDay = usage.sevenDay {
                    UsageCardView(title: "7-Day Window", window: sevenDay)
                }

                if appState.showOpus, let opus = usage.sevenDayOpus, opus.utilization > 0 {
                    UsageCardView(title: "7-Day Opus", window: opus)
                }
            } else if !appState.isLoading && appState.error == nil {
                ContentUnavailableView {
                    Label("No Data", systemImage: "chart.bar")
                } description: {
                    Text("Usage data will appear after first refresh")
                }
            }

            Divider()

            // Credential status
            HStack(spacing: 4) {
                Circle()
                    .fill(credentialStatusColor)
                    .frame(width: 6, height: 6)
                Text("Token: \(appState.credentialManager.credentialStatus.description)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            // Footer
            HStack {
                SettingsLink {
                    Text("Settings...")
                        .font(.caption)
                }
                .buttonStyle(.borderless)

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.borderless)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(width: 280)
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
