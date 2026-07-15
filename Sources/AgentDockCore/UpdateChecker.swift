import Foundation

/// 官网更新源(version.json)的内容
public struct UpdateInfo: Codable, Equatable, Sendable {
    public let version: String
    /// 官网下载链接(现为 DMG;旧版可能仍是 pkg)
    public let download: String
    /// 应用内一键更新用的 DMG;缺省时可回退到 download(若本身是 .dmg)
    public let dmg: String?

    public init(version: String, download: String, dmg: String? = nil) {
        self.version = version
        self.download = download
        self.dmg = dmg
    }

    /// 应用内更新 URL:优先 dmg,否则 download 以 .dmg 结尾时也可用
    public var inAppUpdateURL: URL? {
        if let dmg, let url = URL(string: dmg), url.scheme != nil { return url }
        if download.lowercased().hasSuffix(".dmg"),
           let url = URL(string: download), url.scheme != nil {
            return url
        }
        return nil
    }
}

/// 检查更新:拉取官网 version.json,与当前版本做语义比较
public enum UpdateChecker {
    public static let feedURL = URL(string: "https://agentdockstatus.app/version.json")!

    /// 拉取最新版本信息;10s 超时,绕过本地缓存(更新源必须拿到最新内容)
    public static func fetchLatest(from url: URL = feedURL) async throws -> UpdateInfo {
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(UpdateInfo.self, from: data)
    }

    /// 语义版本比较:`latest` 是否比 `current` 新。容忍 `v` 前缀与位数不齐(1.2 == 1.2.0)
    public static func isNewer(_ latest: String, than current: String) -> Bool {
        let l = components(latest)
        let c = components(current)
        for i in 0..<max(l.count, c.count) {
            let a = i < l.count ? l[i] : 0
            let b = i < c.count ? c[i] : 0
            if a != b { return a > b }
        }
        return false
    }

    private static func components(_ version: String) -> [Int] {
        version.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .trimmingCharacters(in: CharacterSet(charactersIn: "v"))
            .split(separator: ".")
            .map { Int($0.prefix(while: \.isNumber)) ?? 0 }
    }
}
