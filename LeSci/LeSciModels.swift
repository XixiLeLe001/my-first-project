import Foundation

struct BeanDetail: Codable, Equatable, Identifiable {
    var id: String { "\(title)-\(time)-\(amount)" }
    var title: String
    var time: String
    var amount: Int

    static func from(_ value: Any) -> BeanDetail? {
        guard let dict = value as? [String: Any] else { return nil }
        let title = JSON.pickString(dict, ["title", "event", "name", "desc", "description"])
        let time = JSON.pickString(dict, ["time", "date", "createdAt", "createTime"])
        let amount = JSON.pickInt(dict, ["amount", "bean", "num", "count", "value"])
        if title.isEmpty && time.isEmpty && amount == 0 {
            return nil
        }
        return BeanDetail(title: title.isEmpty ? "京豆" : title, time: time, amount: amount)
    }
}

struct JDAccount: Codable, Equatable, Identifiable {
    var id: String { pin.isEmpty ? accountName : pin }
    var pin: String
    var accountName: String
    var cookie: String
    var nickname: String
    var avatarURL: String
    var levelName: String
    var levelIcon: String
    var uploadTime: String
    var checkedAt: String
    var ckStatusCode: String
    var isPlusVip: Bool
    var todayBean: Int
    var yesterdayBean: Int
    var expireSoonBean: Int
    var totalBean: Int
    var jingXiangValue: Int
    var redpacketTotal: Double
    var redpacketExpire: Double
    var recentBeanDetails: [BeanDetail]

    var isValid: Bool {
        let value = ckStatusCode.lowercased()
        return value.isEmpty || value == "valid" || value == "ok" || value == "true"
    }

    var displayName: String {
        if !accountName.isEmpty { return accountName }
        if !nickname.isEmpty { return nickname }
        return pin
    }

    static func fallback(cookie: String, pin: String) -> JDAccount {
        JDAccount(
            pin: pin,
            accountName: pin,
            cookie: cookie,
            nickname: "",
            avatarURL: "",
            levelName: "普通会员",
            levelIcon: "",
            uploadTime: DateFormatter.lesci.string(from: Date()),
            checkedAt: "",
            ckStatusCode: "valid",
            isPlusVip: false,
            todayBean: 0,
            yesterdayBean: 0,
            expireSoonBean: 0,
            totalBean: 0,
            jingXiangValue: 0,
            redpacketTotal: 0,
            redpacketExpire: 0,
            recentBeanDetails: []
        )
    }

    static func from(_ dict: [String: Any], fallbackCookie: String = "", fallbackPin: String = "") -> JDAccount {
        let beanSummary = JSON.pickDict(dict, ["beanSummary"])
        let redpacketSummary = JSON.pickDict(dict, ["redpacketSummary"])
        let details = JSON.pickDict(dict, ["details"])
        let cookie = JSON.pickString(dict, ["cookie", "ck"], fallback: fallbackCookie)
        let extractedPin = CookieTools.extractPin(from: cookie)
        let pin = JSON.pickString(dict, ["pt_pin", "pin", "accountName"], fallback: extractedPin.isEmpty ? fallbackPin : extractedPin)
        let accountName = JSON.pickString(dict, ["accountName", "nickname", "pt_pin", "pin"], fallback: pin)
        let detailsList = JSON.pickArray(beanSummary, ["recentBeanDetails", "todayBeanDetails"])
            + JSON.pickArray(details, ["recent", "today"])

        return JDAccount(
            pin: pin,
            accountName: accountName,
            cookie: cookie,
            nickname: JSON.pickString(beanSummary, ["nickname"], fallback: JSON.pickString(dict, ["nickname"])),
            avatarURL: JSON.pickString(beanSummary, ["headImageUrl", "avatar"], fallback: JSON.pickString(dict, ["headImageUrl", "avatar"])),
            levelName: JSON.pickString(beanSummary, ["levelName"], fallback: JSON.pickString(dict, ["levelName"], fallback: "普通会员")),
            levelIcon: JSON.pickString(beanSummary, ["levelIcon"], fallback: JSON.pickString(dict, ["levelIcon"])),
            uploadTime: JSON.pickString(dict, ["savedAt", "uploadTime", "createdAt", "updatedAt"], fallback: DateFormatter.lesci.string(from: Date())),
            checkedAt: JSON.pickString(redpacketSummary, ["checkedAt"], fallback: JSON.pickString(dict, ["checkedAt"])),
            ckStatusCode: JSON.pickString(dict, ["ckStatusCode", "status"], fallback: JSON.pickBool(dict, ["valid"], fallback: true) ? "valid" : "invalid"),
            isPlusVip: JSON.pickBool(beanSummary, ["isPlusVip"], fallback: JSON.pickBool(dict, ["isPlusVip"])),
            todayBean: JSON.pickInt(beanSummary, ["todayBean", "today"]),
            yesterdayBean: JSON.pickInt(beanSummary, ["yesterdayBean", "yesterday"]),
            expireSoonBean: JSON.pickInt(beanSummary, ["expireSoonBean", "expireSoon"]),
            totalBean: JSON.pickInt(beanSummary, ["totalBean"], fallback: JSON.pickInt(dict, ["totalBean", "beanCount", "jingBean"])),
            jingXiangValue: JSON.pickInt(beanSummary, ["jvalue", "jingXiangTotal", "jingXiangValue", "jdJxValue", "jxValue"], fallback: JSON.pickInt(dict, ["jvalue", "jingXiangTotal"])),
            redpacketTotal: JSON.pickDouble(redpacketSummary, ["totalRedpacket", "redpacketTotal"]),
            redpacketExpire: JSON.pickDouble(redpacketSummary, ["expireSoonRedpacket", "redpacketExpire"]),
            recentBeanDetails: detailsList.compactMap(BeanDetail.from)
        )
    }

    func mergingStats(_ data: [String: Any]) -> JDAccount {
        var merged = self
        let beanSummary = JSON.pickDict(data, ["beanSummary"])
        let redpacketSummary = JSON.pickDict(data, ["redpacketSummary"])
        let stats = beanSummary.isEmpty ? data : beanSummary
        merged.todayBean = JSON.pickInt(stats, ["todayBean", "today"], fallback: merged.todayBean)
        merged.yesterdayBean = JSON.pickInt(stats, ["yesterdayBean", "yesterday"], fallback: merged.yesterdayBean)
        merged.expireSoonBean = JSON.pickInt(stats, ["expireSoonBean", "expireSoon"], fallback: merged.expireSoonBean)
        merged.totalBean = JSON.pickInt(stats, ["totalBean"], fallback: merged.totalBean)
        merged.jingXiangValue = JSON.pickInt(stats, ["jvalue", "jingXiangTotal", "jingXiangValue", "jdJxValue", "jxValue"], fallback: merged.jingXiangValue)
        merged.nickname = JSON.pickString(stats, ["nickname"], fallback: merged.nickname)
        merged.avatarURL = JSON.pickString(stats, ["headImageUrl", "avatar"], fallback: merged.avatarURL)
        merged.levelName = JSON.pickString(stats, ["levelName"], fallback: merged.levelName)
        merged.levelIcon = JSON.pickString(stats, ["levelIcon"], fallback: merged.levelIcon)
        merged.isPlusVip = JSON.pickBool(stats, ["isPlusVip"], fallback: merged.isPlusVip)
        merged.redpacketTotal = JSON.pickDouble(redpacketSummary, ["totalRedpacket", "redpacketTotal"], fallback: merged.redpacketTotal)
        merged.redpacketExpire = JSON.pickDouble(redpacketSummary, ["expireSoonRedpacket", "redpacketExpire"], fallback: merged.redpacketExpire)
        merged.checkedAt = DateFormatter.lesci.string(from: Date())
        let valid = JSON.pickBool(data, ["valid"], fallback: merged.isValid)
        merged.ckStatusCode = valid ? "valid" : "invalid"
        let details = JSON.pickArray(data, ["recentBeanDetails", "todayBeanDetails"]) + JSON.pickArray(JSON.pickDict(data, ["details"]), ["recent", "today"])
        let parsed = details.compactMap(BeanDetail.from)
        if !parsed.isEmpty {
            merged.recentBeanDetails = Array(parsed.prefix(3))
        }
        return merged
    }
}

struct RemoteControlState: Equatable {
    var isAllowed: Bool
    var message: String

    static let allowed = RemoteControlState(isAllowed: true, message: "")
}

enum JSON {
    static func dataObject(_ root: [String: Any]) -> [String: Any] {
        (root["data"] as? [String: Any]) ?? root
    }

    static func pickDict(_ dict: [String: Any], _ keys: [String]) -> [String: Any] {
        for key in keys {
            if let value = dict[key] as? [String: Any] {
                return value
            }
        }
        return [:]
    }

    static func pickArray(_ dict: [String: Any], _ keys: [String]) -> [Any] {
        for key in keys {
            if let value = dict[key] as? [Any] {
                return value
            }
        }
        return []
    }

    static func pickString(_ dict: [String: Any], _ keys: [String], fallback: String = "") -> String {
        for key in keys {
            if let value = dict[key] as? String, !value.isEmpty {
                return value
            }
            if let value = dict[key] as? NSNumber {
                return value.stringValue
            }
        }
        return fallback
    }

    static func pickInt(_ dict: [String: Any], _ keys: [String], fallback: Int = 0) -> Int {
        for key in keys {
            if let value = dict[key] as? Int {
                return value
            }
            if let value = dict[key] as? NSNumber {
                return value.intValue
            }
            if let value = dict[key] as? String, let parsed = Int(value.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return parsed
            }
        }
        return fallback
    }

    static func pickDouble(_ dict: [String: Any], _ keys: [String], fallback: Double = 0) -> Double {
        for key in keys {
            if let value = dict[key] as? Double {
                return value
            }
            if let value = dict[key] as? NSNumber {
                return value.doubleValue
            }
            if let value = dict[key] as? String, let parsed = Double(value.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return parsed
            }
        }
        return fallback
    }

    static func pickBool(_ dict: [String: Any], _ keys: [String], fallback: Bool = false) -> Bool {
        for key in keys {
            if let value = dict[key] as? Bool {
                return value
            }
            if let value = dict[key] as? NSNumber {
                return value.boolValue
            }
            if let value = dict[key] as? String {
                let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if ["true", "1", "valid", "ok", "yes"].contains(normalized) { return true }
                if ["false", "0", "invalid", "no"].contains(normalized) { return false }
            }
        }
        return fallback
    }
}

extension DateFormatter {
    static let lesci: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
}
