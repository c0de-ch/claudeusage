import Foundation

/// Represents the structure of ~/.claude/.credentials.json
struct CredentialsFile: Codable {
    let claudeAiOauth: OAuthCredentials?

    enum CodingKeys: String, CodingKey {
        case claudeAiOauth
    }
}

struct OAuthCredentials: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: String

    var expirationDate: Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: expiresAt) {
            return date
        }
        // Try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: expiresAt)
    }

    var isExpired: Bool {
        guard let expDate = expirationDate else { return true }
        return expDate <= Date()
    }
}

/// Token refresh response from POST /api/oauth/token
struct TokenRefreshResponse: Codable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }
}
