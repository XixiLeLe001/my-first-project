import Foundation

enum CookieTools {
    static func cookieText(from cookies: [HTTPCookie]) -> String? {
        let jdCookies = cookies.filter { cookie in
            let domain = cookie.domain.lowercased()
            return domain.contains("jd.com") || domain.contains("360buy.com")
        }

        guard let ptKey = latestCookie(named: "pt_key", in: jdCookies),
              let ptPin = latestCookie(named: "pt_pin", in: jdCookies),
              !ptKey.value.isEmpty,
              !ptPin.value.isEmpty else {
            return nil
        }

        return "pt_key=\(ptKey.value);pt_pin=\(ptPin.value);"
    }

    static func extractPin(from cookie: String) -> String {
        let parts = cookie.split(separator: ";")
        for part in parts {
            let item = part.trimmingCharacters(in: .whitespacesAndNewlines)
            if item.hasPrefix("pt_pin=") {
                let raw = String(item.dropFirst("pt_pin=".count))
                return raw.removingPercentEncoding ?? raw
            }
        }
        return ""
    }

    private static func latestCookie(named name: String, in cookies: [HTTPCookie]) -> HTTPCookie? {
        cookies
            .filter { $0.name == name }
            .sorted { ($0.expiresDate ?? .distantFuture) > ($1.expiresDate ?? .distantFuture) }
            .first
    }
}
