# Claude Usage

A native macOS menu bar app that displays your Claude Pro/Max subscription usage at a glance.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift 5.10](https://img.shields.io/badge/Swift-5.10-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## Features

- **Menu bar usage display** — See your 5-hour and 7-day utilization without opening a browser
- **Color-coded status** — Green (<50%), yellow (50–80%), red (>80%)
- **Detail popover** — Click for progress bars, percentages, and reset countdowns
- **Opus usage tracking** — Separate display for Opus model usage (Max subscribers)
- **Auto-refresh** — Configurable polling interval (30s to 10m) with exponential backoff on failure
- **Browser sign-in** — Embedded web view for authenticating with claude.ai (no manual cookie extraction)
- **OAuth support** — Automatically reads Claude Code's token from `~/.claude/.credentials.json` if available
- **Token auto-refresh** — Refreshes expired OAuth tokens automatically
- **Notifications** — Optional alerts at 75% and 90% usage thresholds
- **Launch at login** — Uses SMAppService (macOS 13+)
- **No Dock icon** — Runs as a menu bar-only app (`LSUIElement`)

## Screenshots

When running, the app shows a compact usage summary in the menu bar:

```
🧠 5h:42% 7d:18%
```

Click to expand a popover with detailed progress bars and reset countdowns.

## Installation

### Prerequisites

- macOS 14.0 or later
- Xcode 16+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (for generating the Xcode project)

### Build from source

```bash
git clone https://github.com/c0de-ch/claudeusage.git
cd claudeusage

# Generate the Xcode project and open it
brew install xcodegen
xcodegen generate
open ClaudeUsage.xcodeproj
```

Then press **⌘R** in Xcode to build and run. The app will appear in your menu bar.

Alternatively, run the setup script:

```bash
./setup.sh
```

## Authentication

The app supports two authentication methods:

### 1. Browser sign-in (recommended)

Click the app in the menu bar → **Sign in to claude.ai** → log in with your Anthropic account. The app extracts your session cookie and organization ID automatically.

### 2. Claude Code OAuth token (automatic)

If you have [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed and authenticated, the app automatically reads the OAuth token from `~/.claude/.credentials.json`. No setup needed.

## Configuration

Access settings from the popover → **Settings...** or **⌘,**

| Setting | Options | Default |
|---------|---------|---------|
| Refresh interval | 30s, 1m, 2m, 5m, 10m | 1 minute |
| Display windows | 5-Hour, 7-Day, Opus | All enabled |
| Notifications | Alert at 75%, 90% | Disabled |
| Launch at login | On/Off | Off |

## Architecture

```
~/.claude/.credentials.json
    → CredentialManager (read + refresh OAuth token)
        → UsageService (HTTP fetch from /api/oauth/usage)
            → AppState (@Observable, timer-based refresh)
                → MenuBarExtra (SwiftUI menu bar label)
                → UsagePopoverView (click-to-expand detail)
                → SettingsView (preferences)
```

### API endpoints

| Endpoint | Auth | Used for |
|----------|------|----------|
| `GET https://api.anthropic.com/api/oauth/usage` | Bearer token + `anthropic-beta` header | Primary usage data |
| `POST https://api.anthropic.com/api/oauth/token` | Refresh token | Token renewal |
| `GET https://claude.ai/api/organizations/{orgId}/usage` | Session cookie | Fallback if OAuth fails |

## Project structure

```
ClaudeUsage/
├── ClaudeUsageApp.swift              # @main, MenuBarExtra scene
├── Info.plist                        # LSUIElement=YES (no Dock icon)
├── ClaudeUsage.entitlements          # Network + file access
├── Models/
│   ├── UsageResponse.swift           # API response structs
│   └── Credentials.swift             # OAuth credential structs
├── Services/
│   ├── CredentialManager.swift       # Token read/refresh + file watcher
│   ├── UsageService.swift            # HTTP client (OAuth + cookie fallback)
│   └── RefreshScheduler.swift        # Timer with exponential backoff
├── ViewModels/
│   └── AppState.swift                # Central @Observable state
├── Views/
│   ├── UsagePopoverView.swift        # Detail popover with progress bars
│   ├── UsageCardView.swift           # Reusable progress bar card
│   ├── CookieAuthView.swift          # Embedded WKWebView for browser sign-in
│   └── SettingsView.swift            # Preferences (3 tabs)
├── Utilities/
│   ├── TimeFormatting.swift          # Countdown + relative time formatting
│   └── LaunchAtLogin.swift           # SMAppService wrapper
└── Assets.xcassets/
```

## Related projects

- [P233/claude-usage.app](https://github.com/P233/claude-usage.app) — Similar macOS app using the web API
- [steipete/CodexBar](https://github.com/steipete/CodexBar) — Documents OAuth, Web API, and CLI approaches
- [backmind/ClaudeUsage](https://github.com/backmind/ClaudeUsage) — PowerShell module for usage queries

## License

MIT
