import Foundation
import SwiftUI
import UserNotifications

@Observable
final class AppState {
    // MARK: - Services
    let credentialManager = CredentialManager()
    let scheduler = RefreshScheduler()
    private(set) var usageService: UsageService?

    // MARK: - Usage Data
    private(set) var usage: UsageResponse?
    private(set) var lastUpdated: Date?
    private(set) var isLoading = false
    private(set) var error: String?

    // MARK: - Settings (stored properties synced to UserDefaults)
    var refreshInterval: TimeInterval {
        didSet {
            UserDefaults.standard.set(refreshInterval, forKey: "refreshInterval")
            scheduler.baseInterval = refreshInterval
        }
    }

    var showFiveHour: Bool {
        didSet { UserDefaults.standard.set(showFiveHour, forKey: "showFiveHour") }
    }

    var showSevenDay: Bool {
        didSet { UserDefaults.standard.set(showSevenDay, forKey: "showSevenDay") }
    }

    var showOpus: Bool {
        didSet { UserDefaults.standard.set(showOpus, forKey: "showOpus") }
    }

    var notifyAt75: Bool {
        didSet { UserDefaults.standard.set(notifyAt75, forKey: "notifyAt75") }
    }

    var notifyAt90: Bool {
        didSet { UserDefaults.standard.set(notifyAt90, forKey: "notifyAt90") }
    }

    // Fallback cookie-based auth
    var sessionCookie: String {
        didSet { UserDefaults.standard.set(sessionCookie, forKey: "sessionCookie") }
    }

    var organizationId: String {
        didSet { UserDefaults.standard.set(organizationId, forKey: "organizationId") }
    }

    init() {
        let defaults = UserDefaults.standard
        let storedInterval = defaults.double(forKey: "refreshInterval")
        self.refreshInterval = storedInterval > 0 ? storedInterval : 60
        self.showFiveHour = defaults.object(forKey: "showFiveHour") as? Bool ?? true
        self.showSevenDay = defaults.object(forKey: "showSevenDay") as? Bool ?? true
        self.showOpus = defaults.object(forKey: "showOpus") as? Bool ?? true
        self.notifyAt75 = defaults.object(forKey: "notifyAt75") as? Bool ?? false
        self.notifyAt90 = defaults.object(forKey: "notifyAt90") as? Bool ?? false
        self.sessionCookie = defaults.string(forKey: "sessionCookie") ?? ""
        self.organizationId = defaults.string(forKey: "organizationId") ?? ""
    }

    // MARK: - Auth State

    var needsSignIn: Bool {
        credentialManager.credentialStatus == .unknown
        && credentialManager.credentialStatus != .loaded
        && sessionCookie.isEmpty
    }

    var hasWebAuth: Bool {
        !sessionCookie.isEmpty && !organizationId.isEmpty
    }

    func applyWebAuth(cookie: String, orgId: String) {
        sessionCookie = cookie
        organizationId = orgId
        // Restart fetching with the new credentials
        Task {
            _ = await performRefresh()
            if !scheduler.isRunning {
                scheduler.start()
            }
        }
    }

    // MARK: - Computed Properties

    var menuBarText: String {
        guard let usage else {
            if isLoading { return "⏳" }
            if needsSignIn { return "Sign in" }
            if error != nil { return "⚠️" }
            return "—"
        }

        var parts: [(prefix: String, value: Int)] = []

        if showFiveHour, let fh = usage.fiveHour {
            parts.append(("5h", fh.percentage))
        }
        if showSevenDay, let sd = usage.sevenDay {
            parts.append(("7d", sd.percentage))
        }
        if showOpus, let op = usage.sevenDayOpus, op.utilization > 0 {
            parts.append(("Op", op.percentage))
        }

        if parts.isEmpty { return "—" }

        // When only one window is shown, display just the percentage
        if parts.count == 1 {
            return "\(parts[0].value)%"
        }

        return parts.map { "\($0.prefix):\($0.value)%" }.joined(separator: " ")
    }

    var menuBarColor: Color {
        let values = [
            showFiveHour ? usage?.fiveHour?.utilization : nil,
            showSevenDay ? usage?.sevenDay?.utilization : nil,
            showOpus ? usage?.sevenDayOpus?.utilization : nil,
        ].compactMap { $0 }

        guard let maxVal = values.max() else { return .primary }

        switch maxVal {
        case ..<50: return .green
        case 50..<80: return .yellow
        default: return .red
        }
    }

    // MARK: - Lifecycle

    private var hasStarted = false

    func startIfNeeded() {
        guard !hasStarted else { return }
        hasStarted = true
        // Defer to next run loop iteration to avoid layout recursion
        // in MenuBarExtra during initial setup
        DispatchQueue.main.async {
            self.start()
        }
    }

    func start() {
        usageService = UsageService(credentialManager: credentialManager)
        credentialManager.startFileWatcher()

        scheduler.baseInterval = refreshInterval
        scheduler.onRefresh = { [weak self] in
            guard let self else { return false }
            return await self.performRefresh()
        }

        Task {
            _ = await performRefresh()
            scheduler.start()
        }
    }

    func stop() {
        scheduler.stop()
        credentialManager.stopFileWatcher()
    }

    func manualRefresh() {
        scheduler.triggerNow()
    }

    @discardableResult
    private func performRefresh() async -> Bool {
        isLoading = true
        error = nil

        // Try OAuth first
        do {
            let response = try await usageService?.fetchUsage()
            usage = response
            lastUpdated = Date()
            isLoading = false
            checkNotificationThresholds(response)
            return true
        } catch {
            // If OAuth fails and we have cookie auth, try that
            if hasWebAuth {
                return await performWebRefresh()
            }

            // If it's just a missing credentials file and no web auth, don't show as error
            if case CredentialError.fileNotFound = error {
                self.error = nil
            } else if case CredentialError.noOAuthCredentials = error {
                self.error = nil
            } else {
                self.error = error.localizedDescription
            }
            isLoading = false
            return false
        }
    }

    private func performWebRefresh() async -> Bool {
        do {
            let webService = WebUsageService(sessionCookie: sessionCookie, organizationId: organizationId)
            let response = try await webService.fetchUsage()
            usage = response
            lastUpdated = Date()
            isLoading = false
            checkNotificationThresholds(response)
            return true
        } catch {
            self.error = error.localizedDescription
            isLoading = false
            return false
        }
    }

    // MARK: - Notifications

    private var notifiedAt75 = Set<String>()
    private var notifiedAt90 = Set<String>()

    private func checkNotificationThresholds(_ response: UsageResponse?) {
        guard let response else { return }

        if notifyAt75 {
            checkThreshold(window: response.fiveHour, name: "5-Hour", threshold: 75, notified: &notifiedAt75)
            checkThreshold(window: response.sevenDay, name: "7-Day", threshold: 75, notified: &notifiedAt75)
        }

        if notifyAt90 {
            checkThreshold(window: response.fiveHour, name: "5-Hour", threshold: 90, notified: &notifiedAt90)
            checkThreshold(window: response.sevenDay, name: "7-Day", threshold: 90, notified: &notifiedAt90)
        }
    }

    private func checkThreshold(window: UsageWindow?, name: String, threshold: Int, notified: inout Set<String>) {
        guard let window, window.percentage >= threshold else { return }
        let key = "\(name)-\(threshold)"
        guard !notified.contains(key) else { return }
        notified.insert(key)
        sendNotification(title: "Claude Usage Alert", body: "\(name) usage at \(window.percentage)%")
    }

    private func sendNotification(title: String, body: String) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        center.add(request)
    }
}
