import Foundation

@Observable
final class RefreshScheduler {
    private var timer: Timer?
    private var consecutiveFailures = 0
    private let maxBackoffMultiplier = 8 // Max 8x the base interval

    var baseInterval: TimeInterval = 60 {
        didSet {
            if isRunning {
                restart()
            }
        }
    }

    private(set) var isRunning = false
    private(set) var nextRefreshDate: Date?

    var onRefresh: (() async -> Bool)? // Returns true on success

    var currentInterval: TimeInterval {
        if consecutiveFailures == 0 {
            return baseInterval
        }
        let multiplier = min(pow(2.0, Double(consecutiveFailures - 1)), Double(maxBackoffMultiplier))
        return baseInterval * multiplier
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        scheduleNext()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        nextRefreshDate = nil
    }

    func restart() {
        stop()
        consecutiveFailures = 0
        start()
    }

    func triggerNow() {
        timer?.invalidate()
        timer = nil
        Task { @MainActor in
            await fireRefresh()
            if isRunning {
                scheduleNext()
            }
        }
    }

    func reportSuccess() {
        consecutiveFailures = 0
    }

    func reportFailure() {
        consecutiveFailures += 1
    }

    private func scheduleNext() {
        let interval = currentInterval
        nextRefreshDate = Date().addingTimeInterval(interval)

        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.fireRefresh()
                if self.isRunning {
                    self.scheduleNext()
                }
            }
        }
    }

    private func fireRefresh() async {
        guard let onRefresh else { return }
        let success = await onRefresh()
        if success {
            reportSuccess()
        } else {
            reportFailure()
        }
    }
}
