import AppKit
import SwiftUI

struct UsagePopoverView: View {
    let appState: AppState
    @State private var showingCookieAuth = false

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
                } else if appState.usage != nil {
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

            // Sign-in prompt when no auth is available
            if appState.needsSignIn && appState.usage == nil && !appState.isLoading {
                VStack(spacing: 10) {
                    Image(systemName: "person.crop.circle.badge.questionmark")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text("Sign in to view your usage")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button("Sign in to claude.ai") {
                        showingCookieAuth = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
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
            }

            Divider()

            // Auth status
            HStack(spacing: 4) {
                Circle()
                    .fill(authStatusColor)
                    .frame(width: 6, height: 6)
                Text(authStatusText)
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
        .sheet(isPresented: $showingCookieAuth) {
            CookieAuthView(
                onComplete: { cookie, orgId in
                    appState.applyWebAuth(cookie: cookie, orgId: orgId)
                    showingCookieAuth = false
                },
                onCancel: {
                    showingCookieAuth = false
                }
            )
        }
    }

    private var authStatusColor: Color {
        if appState.hasWebAuth || appState.credentialManager.credentialStatus == .loaded {
            return .green
        }
        if appState.credentialManager.credentialStatus == .refreshing {
            return .yellow
        }
        if appState.needsSignIn {
            return .gray
        }
        return .red
    }

    private var authStatusText: String {
        if appState.credentialManager.credentialStatus == .loaded {
            return "OAuth token active"
        }
        if appState.hasWebAuth {
            return "Web session active"
        }
        return "Not signed in"
    }
}
