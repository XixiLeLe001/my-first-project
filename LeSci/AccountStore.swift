import Foundation
import UIKit

@MainActor
final class AccountStore: ObservableObject {
    @Published private(set) var accounts: [JDAccount] = []
    @Published var isLoading = false
    @Published var toast: String?
    @Published var remoteControl = RemoteControlState.allowed
    @Published var lastError: String?

    private let api = LeSciAPI()
    private let defaults = UserDefaults.standard
    private var didStart = false

    private enum Key {
        static let accounts = "lesci.ios.accounts"
        static let hiddenPins = "lesci.ios.hiddenPins"
        static let ownedPins = "lesci.ios.ownedPins"
        static let deviceId = "lesci.ios.deviceId"
        static let deviceToken = "lesci.ios.deviceToken"
    }

    init() {
        loadFromDisk()
    }

    var visibleAccounts: [JDAccount] {
        let hidden = hiddenPins
        return accounts.filter { !hidden.contains($0.pin) }
    }

    var hiddenPins: Set<String> {
        Set(defaults.stringArray(forKey: Key.hiddenPins) ?? [])
    }

    var ownedPins: Set<String> {
        Set(defaults.stringArray(forKey: Key.ownedPins) ?? [])
    }

    var accountStatusText: String {
        let list = visibleAccounts
        let total = list.count
        let valid = list.filter(\.isValid).count
        let invalid = max(total - valid, 0)
        guard total > 0 else { return "" }

        let mood: String
        if valid == total {
            mood = pickStable([
                "目前账号都有效哦，状态满分～",
                "账号们今天状态不错，全部可用～",
                "当前账号全都很争气",
                "队伍整整齐齐，全部有效"
            ], seed: total + valid)
        } else if valid == 0 {
            mood = pickStable([
                "今天账号们集体请假了…",
                "当前没有可用账号哦",
                "账号列表全员离线，稍后再试试吧",
                "看起来账号们都需要重新唤醒一下"
            ], seed: total + invalid)
        } else {
            mood = pickStable([
                "有的在线，有的开小差了～",
                "当前部分账号可用，部分账号待唤醒",
                "队伍还算整齐，就是有几个掉队了",
                "一部分状态在线，另一部分需要关照一下"
            ], seed: total + valid + invalid)
        }

        return "本地已缓存 \(total) 个账号，有效账号 \(valid) 个，无效账号 \(invalid) 个\n\(mood)"
    }

    var emptyCopy: (title: String, subtitle: String) {
        pickStable([
            ("账号列表空空如也", "快添加一个账号，让我帮你盯着京豆和状态～"),
            ("暂无京东账号", "添加账号后，可查看状态、京豆和京享值"),
            ("你的京豆雷达还没启动", "添加京东账号，看看今天有多少京豆在线～")
        ], seed: Calendar.current.component(.day, from: Date()))
    }

    func startupRefresh() async {
        guard !didStart else { return }
        didStart = true
        loadFromDisk()
        await checkRemoteControl()
        if remoteControl.isAllowed, !accounts.isEmpty {
            await refreshAccounts(keepCacheOnFail: true)
        }
    }

    func checkRemoteControl() async {
        do {
            remoteControl = try await api.fetchRemoteControl()
            if !remoteControl.isAllowed {
                showToast(remoteControl.message)
            }
        } catch {
            // 远程控制失败不阻断已安装 App，避免服务器短暂失联导致用户打不开。
            remoteControl = .allowed
        }
    }

    func uploadCookie(_ cookie: String) async throws {
        let pin = CookieTools.extractPin(from: cookie)
        guard !pin.isEmpty else { throw LeSciAPIError.invalidResponse }
        let token = try await ensureDeviceToken()
        isLoading = true
        defer { isLoading = false }

        var account = try await api.uploadCookie(cookie, deviceToken: token)
        if account.cookie.isEmpty { account.cookie = cookie }
        if account.pin.isEmpty { account.pin = pin }
        if account.accountName.isEmpty { account.accountName = pin }
        account.ckStatusCode = account.ckStatusCode.isEmpty ? "valid" : account.ckStatusCode

        rememberOwnedPin(account.pin)
        upsert(account)
        saveAccounts()
        showToast("上传数据成功")
        await refreshAccounts(keepCacheOnFail: true)
    }

    func refreshAccounts(keepCacheOnFail: Bool) async {
        guard !isLoading else { return }
        guard remoteControl.isAllowed else {
            showToast(remoteControl.message)
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let token = try await ensureDeviceToken()
            var fetched = try await api.fetchAccounts(deviceToken: token)
            let owned = ownedPins
            if !owned.isEmpty {
                fetched = fetched.filter { owned.contains($0.pin) || owned.contains($0.accountName) }
            }

            if fetched.isEmpty, keepCacheOnFail {
                lastError = nil
                return
            }

            var enriched: [JDAccount] = []
            for account in fetched {
                do {
                    let stats = try await api.fetchBeanStats(pin: account.pin, deviceToken: token)
                    enriched.append(account.mergingStats(stats))
                } catch {
                    enriched.append(account)
                }
            }

            accounts = preserveLocalData(in: enriched)
            saveAccounts()
            lastError = nil
        } catch {
            if !keepCacheOnFail || accounts.isEmpty {
                lastError = "服务器已失联"
            } else {
                lastError = nil
                showToast("服务器已失联，已使用上次缓存")
            }
        }
    }

    func hideAccountFromDisplay(_ account: JDAccount) {
        var hidden = hiddenPins
        hidden.insert(account.pin)
        defaults.set(Array(hidden), forKey: Key.hiddenPins)
        showToast("已从页面隐藏，不会删除后台数据")
    }

    func copyQQRobot() {
        UIPasteboard.general.string = LeSciConfig.qqRobot
        showToast("QQ机器人已复制")
    }

    func copyWechatRobot() {
        UIPasteboard.general.string = LeSciConfig.wechatRobot
        showToast("微信机器人已复制")
    }

    func copySecret(for account: JDAccount) {
        UIPasteboard.general.string = account.cookie
        showToast("神秘数据已复制")
    }

    func showToast(_ message: String) {
        toast = message
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_600_000_000)
            await MainActor.run {
                if self?.toast == message {
                    self?.toast = nil
                }
            }
        }
    }

    private func ensureDeviceToken() async throws -> String {
        if let token = defaults.string(forKey: Key.deviceToken), !token.isEmpty {
            return token
        }
        let deviceId = ensureDeviceId()
        let token = try await api.loginDevice(deviceId: deviceId)
        defaults.set(token, forKey: Key.deviceToken)
        return token
    }

    private func ensureDeviceId() -> String {
        if let value = defaults.string(forKey: Key.deviceId), !value.isEmpty {
            return value
        }
        let value = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        defaults.set(value, forKey: Key.deviceId)
        return value
    }

    private func upsert(_ account: JDAccount) {
        if let index = accounts.firstIndex(where: { $0.pin == account.pin }) {
            accounts[index] = mergeLocal(accounts[index], into: account)
        } else {
            accounts.append(account)
        }
    }

    private func preserveLocalData(in newAccounts: [JDAccount]) -> [JDAccount] {
        newAccounts.map { remote in
            if let local = accounts.first(where: { $0.pin == remote.pin }) {
                return mergeLocal(local, into: remote)
            }
            return remote
        }
    }

    private func mergeLocal(_ local: JDAccount, into remote: JDAccount) -> JDAccount {
        var result = remote
        if result.cookie.isEmpty { result.cookie = local.cookie }
        if result.avatarURL.isEmpty { result.avatarURL = local.avatarURL }
        if result.uploadTime.isEmpty { result.uploadTime = local.uploadTime }
        if result.totalBean == 0 { result.totalBean = local.totalBean }
        if result.jingXiangValue == 0 { result.jingXiangValue = local.jingXiangValue }
        if result.recentBeanDetails.isEmpty { result.recentBeanDetails = local.recentBeanDetails }
        return result
    }

    private func rememberOwnedPin(_ pin: String) {
        guard !pin.isEmpty else { return }
        var pins = ownedPins
        pins.insert(pin)
        defaults.set(Array(pins), forKey: Key.ownedPins)
    }

    private func saveAccounts() {
        guard let data = try? JSONEncoder().encode(accounts) else { return }
        defaults.set(data, forKey: Key.accounts)
    }

    private func loadFromDisk() {
        guard let data = defaults.data(forKey: Key.accounts),
              let saved = try? JSONDecoder().decode([JDAccount].self, from: data) else {
            accounts = []
            return
        }
        accounts = saved
    }

    private func pickStable<T>(_ values: [T], seed: Int) -> T {
        values[abs(seed) % values.count]
    }
}
