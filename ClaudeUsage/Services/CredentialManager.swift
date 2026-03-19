import Darwin
import Foundation

enum CredentialError: LocalizedError {
    case fileNotFound
    case noOAuthCredentials
    case tokenExpiredNoRefresh
    case refreshFailed(String)
    case invalidData

    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "Credentials file not found at ~/.claude/.credentials.json"
        case .noOAuthCredentials:
            return "No OAuth credentials found in credentials file"
        case .tokenExpiredNoRefresh:
            return "Token expired and no refresh token available"
        case .refreshFailed(let reason):
            return "Token refresh failed: \(reason)"
        case .invalidData:
            return "Invalid credentials data"
        }
    }
}

@Observable
final class CredentialManager {
    private(set) var currentToken: String?
    private(set) var credentialStatus: CredentialStatus = .unknown

    private var credentials: OAuthCredentials?
    private var fileWatcherSource: DispatchSourceFileSystemObject?

    enum CredentialStatus: Equatable {
        case unknown
        case loaded
        case expired
        case refreshing
        case error(String)

        var description: String {
            switch self {
            case .unknown: return "Not loaded"
            case .loaded: return "Active"
            case .expired: return "Expired"
            case .refreshing: return "Refreshing..."
            case .error(let msg): return "Error: \(msg)"
            }
        }
    }

    private var credentialsPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/.claude/.credentials.json"
    }

    func loadCredentials() async throws -> String {
        let url = URL(fileURLWithPath: credentialsPath)

        guard FileManager.default.fileExists(atPath: credentialsPath) else {
            credentialStatus = .error("File not found")
            throw CredentialError.fileNotFound
        }

        let data = try Data(contentsOf: url)
        let file = try JSONDecoder().decode(CredentialsFile.self, from: data)

        guard let oauth = file.claudeAiOauth else {
            credentialStatus = .error("No OAuth credentials")
            throw CredentialError.noOAuthCredentials
        }

        credentials = oauth

        if oauth.isExpired {
            return try await refreshToken(oauth)
        }

        currentToken = oauth.accessToken
        credentialStatus = .loaded
        return oauth.accessToken
    }

    func getValidToken() async throws -> String {
        if let credentials, !credentials.isExpired, let token = currentToken {
            return token
        }
        return try await loadCredentials()
    }

    private func refreshToken(_ oauth: OAuthCredentials) async throws -> String {
        credentialStatus = .refreshing

        let url = URL(string: "https://api.anthropic.com/api/oauth/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "grant_type": "refresh_token",
            "refresh_token": oauth.refreshToken,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            credentialStatus = .error("Invalid response")
            throw CredentialError.refreshFailed("Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "unknown"
            credentialStatus = .error("HTTP \(httpResponse.statusCode)")
            throw CredentialError.refreshFailed("HTTP \(httpResponse.statusCode): \(body)")
        }

        let refreshResponse = try JSONDecoder().decode(TokenRefreshResponse.self, from: data)
        currentToken = refreshResponse.accessToken
        credentialStatus = .loaded

        // Update stored credentials with new tokens
        try await updateStoredCredentials(
            accessToken: refreshResponse.accessToken,
            refreshToken: refreshResponse.refreshToken ?? oauth.refreshToken,
            expiresIn: refreshResponse.expiresIn
        )

        return refreshResponse.accessToken
    }

    private func updateStoredCredentials(accessToken: String, refreshToken: String, expiresIn: Int) async throws {
        let url = URL(fileURLWithPath: credentialsPath)
        let data = try Data(contentsOf: url)

        guard var json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              var oauthJson = json["claudeAiOauth"] as? [String: Any] else {
            return
        }

        let expiresAt = ISO8601DateFormatter().string(from: Date().addingTimeInterval(TimeInterval(expiresIn)))

        oauthJson["accessToken"] = accessToken
        oauthJson["refreshToken"] = refreshToken
        oauthJson["expiresAt"] = expiresAt
        json["claudeAiOauth"] = oauthJson

        let updatedData = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
        try updatedData.write(to: url, options: .atomic)
    }

    func startFileWatcher() {
        stopFileWatcher()

        let fd = open(credentialsPath, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename],
            queue: .main
        )

        source.setEventHandler { [weak self] in
            Task {
                try? await self?.loadCredentials()
            }
        }

        source.setCancelHandler {
            close(fd)
        }

        source.resume()
        fileWatcherSource = source
    }

    func stopFileWatcher() {
        fileWatcherSource?.cancel()
        fileWatcherSource = nil
    }
}
