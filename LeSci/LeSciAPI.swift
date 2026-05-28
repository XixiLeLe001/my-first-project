import Foundation

enum LeSciAPIError: LocalizedError {
    case badURL
    case invalidResponse
    case badStatus(Int, String)
    case serverOffline

    var errorDescription: String? {
        switch self {
        case .badURL:
            return "接口地址无效"
        case .invalidResponse:
            return "服务器返回数据异常"
        case .badStatus:
            return "请求失败"
        case .serverOffline:
            return "服务器已失联"
        }
    }
}

final class LeSciAPI {
    private let session: URLSession

    init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 30
        session = URLSession(configuration: configuration)
    }

    func loginDevice(deviceId: String) async throws -> String {
        let encoded = deviceId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? deviceId
        let root = try await requestJSON(method: "GET", path: "/device/login?deviceId=\(encoded)", body: nil, token: nil)
        let data = JSON.dataObject(root)
        let token = JSON.pickString(data, ["deviceToken", "token", "accessToken"], fallback: JSON.pickString(root, ["deviceToken", "token", "accessToken"]))
        guard !token.isEmpty else { throw LeSciAPIError.invalidResponse }
        return token
    }

    func uploadCookie(_ cookie: String, deviceToken: String) async throws -> JDAccount {
        let pin = CookieTools.extractPin(from: cookie)
        let root = try await requestJSON(
            method: "POST",
            path: "/android/ck",
            body: ["ck": cookie, "deviceToken": deviceToken],
            token: deviceToken
        )
        let data = JSON.dataObject(root)
        if let accountDict = data["account"] as? [String: Any] {
            return JDAccount.from(accountDict, fallbackCookie: cookie, fallbackPin: pin)
        }
        return JDAccount.fallback(cookie: cookie, pin: pin)
    }

    func fetchAccounts(deviceToken: String) async throws -> [JDAccount] {
        let root = try await requestJSON(method: "POST", path: "/android/accounts", body: nil, token: deviceToken)
        let data = JSON.dataObject(root)
        let rawAccounts = JSON.pickArray(data, ["accounts"])
        return rawAccounts.compactMap { item in
            guard let dict = item as? [String: Any] else { return nil }
            return JDAccount.from(dict)
        }
    }

    func fetchBeanStats(pin: String, deviceToken: String) async throws -> [String: Any] {
        let encoded = pin.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? pin
        let root = try await requestJSON(method: "GET", path: "/android/bean-stats?pin=\(encoded)", body: nil, token: deviceToken)
        return JSON.dataObject(root)
    }

    func fetchRemoteControl() async throws -> RemoteControlState {
        let root = try await requestJSON(method: "GET", path: "/android/app-control", body: nil, token: nil)
        let data = JSON.dataObject(root)
        let enabled = JSON.pickBool(data, ["enabled"], fallback: true)
        let disabled = JSON.pickBool(data, ["disabled"])
        let forceUpgrade = JSON.pickBool(data, ["forceUpgrade"])
        let needUpgrade = JSON.pickBool(data, ["needUpgrade"])
        let blocked = disabled || forceUpgrade || needUpgrade || !enabled
        let message = JSON.pickString(
            data,
            ["notice", "message", "downloadText"],
            fallback: blocked ? "当前版本已停止服务，请按机器人通知前往指定位置下载最新版。" : ""
        )
        return RemoteControlState(isAllowed: !blocked, message: message)
    }

    private func requestJSON(method: String, path: String, body: [String: Any]?, token: String?) async throws -> [String: Any] {
        guard let url = makeURL(path: path) else {
            throw LeSciAPIError.badURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(LeSciConfig.appKey, forHTTPHeaderField: "X-App-Key")
        request.setValue(LeSciConfig.appSign, forHTTPHeaderField: "X-App-Sign")

        if let token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        }

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw LeSciAPIError.invalidResponse
            }

            let responseText = String(data: data, encoding: .utf8) ?? ""
            guard (200..<300).contains(http.statusCode) else {
                throw LeSciAPIError.badStatus(http.statusCode, responseText)
            }

            guard !data.isEmpty else { return [:] }
            let object = try JSONSerialization.jsonObject(with: data, options: [])
            if let dict = object as? [String: Any] {
                return dict
            }
            if let array = object as? [Any] {
                return ["data": array]
            }
            throw LeSciAPIError.invalidResponse
        } catch let error as LeSciAPIError {
            throw error
        } catch {
            throw LeSciAPIError.serverOffline
        }
    }

    private func makeURL(path: String) -> URL? {
        if path.hasPrefix("http://") || path.hasPrefix("https://") {
            return URL(string: path)
        }
        return URL(string: LeSciConfig.server.absoluteString + path)
    }
}
