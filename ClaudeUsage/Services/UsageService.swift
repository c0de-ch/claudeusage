import Foundation

enum UsageServiceError: LocalizedError {
    case unauthorized
    case rateLimited(retryAfter: TimeInterval?)
    case serverError(Int)
    case networkError(Error)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Unauthorized — token may be invalid"
        case .rateLimited(let retryAfter):
            if let retry = retryAfter {
                return "Rate limited — retry after \(Int(retry))s"
            }
            return "Rate limited"
        case .serverError(let code):
            return "Server error (HTTP \(code))"
        case .networkError(let error):
            return error.localizedDescription
        case .invalidResponse:
            return "Invalid response from server"
        }
    }
}

final class UsageService {
    private let credentialManager: CredentialManager
    private let baseURL = "https://api.anthropic.com/api/oauth/usage"

    init(credentialManager: CredentialManager) {
        self.credentialManager = credentialManager
    }

    func fetchUsage() async throws -> UsageResponse {
        let token = try await credentialManager.getValidToken()
        return try await performRequest(token: token)
    }

    private func performRequest(token: String, isRetry: Bool = false) async throws -> UsageResponse {
        guard let url = URL(string: baseURL) else {
            throw UsageServiceError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw UsageServiceError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw UsageServiceError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            let decoder = JSONDecoder()
            return try decoder.decode(UsageResponse.self, from: data)

        case 401:
            if !isRetry {
                // Token might be stale — force refresh and retry once
                let newToken = try await credentialManager.loadCredentials()
                return try await performRequest(token: newToken, isRetry: true)
            }
            throw UsageServiceError.unauthorized

        case 429:
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                .flatMap { TimeInterval($0) }
            throw UsageServiceError.rateLimited(retryAfter: retryAfter)

        case 500...599:
            throw UsageServiceError.serverError(httpResponse.statusCode)

        default:
            throw UsageServiceError.invalidResponse
        }
    }
}

/// Fallback service using the web API with a session cookie
final class WebUsageService {
    private let sessionCookie: String
    private let organizationId: String

    init(sessionCookie: String, organizationId: String) {
        self.sessionCookie = sessionCookie
        self.organizationId = organizationId
    }

    func fetchUsage() async throws -> UsageResponse {
        let urlString = "https://claude.ai/api/organizations/\(organizationId)/usage"
        guard let url = URL(string: urlString) else {
            throw UsageServiceError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("sessionKey=\(sessionCookie)", forHTTPHeaderField: "Cookie")
        request.setValue("https://claude.ai", forHTTPHeaderField: "Origin")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw UsageServiceError.invalidResponse
        }

        return try JSONDecoder().decode(UsageResponse.self, from: data)
    }
}
