import SwiftUI
import WebKit

struct CookieAuthView: View {
    let onComplete: (String, String) -> Void // (sessionCookie, organizationId)
    let onCancel: () -> Void

    @State private var status = "Sign in to claude.ai below"
    @State private var isExtracting = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if isExtracting {
                    ProgressView()
                        .controlSize(.small)
                }
                Button("Cancel") { onCancel() }
                    .buttonStyle(.borderless)
                    .font(.caption)
            }
            .padding(8)

            Divider()

            WebViewRepresentable(
                url: URL(string: "https://claude.ai/login")!,
                onCookieFound: { cookie in
                    isExtracting = true
                    status = "Got session cookie, fetching org ID..."
                    Task {
                        await fetchOrgAndComplete(cookie: cookie)
                    }
                }
            )
        }
        .frame(width: 500, height: 600)
    }

    private func fetchOrgAndComplete(cookie: String) async {
        // Fetch org ID from the API using the session cookie
        guard let url = URL(string: "https://claude.ai/api/organizations") else {
            status = "Got cookie but failed to fetch org ID"
            onComplete(cookie, "")
            return
        }

        var request = URLRequest(url: url)
        request.setValue("sessionKey=\(cookie)", forHTTPHeaderField: "Cookie")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let orgs = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
               let orgId = orgs.first?["uuid"] as? String {
                status = "Done!"
                onComplete(cookie, orgId)
            } else {
                status = "Got cookie, enter org ID manually"
                onComplete(cookie, "")
            }
        } catch {
            status = "Got cookie, enter org ID manually"
            onComplete(cookie, "")
        }
    }
}

struct WebViewRepresentable: NSViewRepresentable {
    let url: URL
    let onCookieFound: (String) -> Void

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCookieFound: onCookieFound)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        let onCookieFound: (String) -> Void
        private var found = false

        init(onCookieFound: @escaping (String) -> Void) {
            self.onCookieFound = onCookieFound
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard !found else { return }
            checkForSessionCookie(in: webView)
        }

        private func checkForSessionCookie(in webView: WKWebView) {
            webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
                guard let self, !self.found else { return }
                if let sessionCookie = cookies.first(where: { $0.name == "lastActiveOrg" || $0.name == "sessionKey" }),
                   sessionCookie.name == "sessionKey" {
                    self.found = true
                    DispatchQueue.main.async {
                        self.onCookieFound(sessionCookie.value)
                    }
                } else {
                    // Keep polling after navigations (login redirects)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        self.checkForSessionCookie(in: webView)
                    }
                }
            }
        }
    }
}
