import Foundation

struct UpdateInfo {
    let version: String
    let tagName: String
    let releaseURL: URL
    let downloadURL: URL?
    let releaseNotes: String?
    let isRolling: Bool
    let publishedAt: TimeInterval?
}

enum UpdateChecker {
    static let githubRepo = "sameerbajaj/MacYT"
    static let releasesPage = URL(string: "https://github.com/\(githubRepo)/releases")!

    static func check() async -> UpdateInfo? {
        let apiURL = URL(string: "https://api.github.com/repos/\(githubRepo)/releases")!
        var request = URLRequest(url: apiURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("MacYT", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10

        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let releases = try? JSONDecoder().decode([GitHubRelease].self, from: data) else {
            return nil
        }

        if let newest = releases.first(where: { !$0.draft && !$0.prerelease && $0.tagName != "latest" }) {
            let remoteVersion = normalise(newest.tagName)
            let localVersion = normalise(currentVersion)
            if isNewer(remoteVersion, than: localVersion) {
                return UpdateInfo(
                    version: remoteVersion,
                    tagName: newest.tagName,
                    releaseURL: URL(string: newest.htmlURL) ?? releasesPage,
                    downloadURL: preferredDMGURL(in: newest),
                    releaseNotes: newest.body,
                    isRolling: false,
                    publishedAt: newest.publishedAt
                )
            }
        }

        if let latest = releases.first(where: { $0.tagName == "latest" }),
           let publishedAt = latest.publishedAt {
            let baseline = max(buildTimestamp, lastInstalledRollingTimestamp)
            if baseline > 0 && publishedAt > baseline + 60 {
                return UpdateInfo(
                    version: "latest",
                    tagName: "latest",
                    releaseURL: URL(string: latest.htmlURL) ?? releasesPage,
                    downloadURL: preferredDMGURL(in: latest),
                    releaseNotes: latest.body,
                    isRolling: true,
                    publishedAt: publishedAt
                )
            }
        }

        return nil
    }

    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    static var buildTimestamp: TimeInterval {
        guard let value = Bundle.main.infoDictionary?["CFBundleVersion"] as? String,
              let timestamp = TimeInterval(value) else {
            return 0
        }
        return timestamp
    }

    private static let lastInstalledKey = "lastInstalledRollingTimestamp"

    static var lastInstalledRollingTimestamp: TimeInterval {
        UserDefaults.standard.double(forKey: lastInstalledKey)
    }

    static func recordInstalledRollingTimestamp(_ publishedAt: TimeInterval) {
        UserDefaults.standard.set(publishedAt, forKey: lastInstalledKey)
    }

    private static func normalise(_ tag: String) -> String {
        var value = tag
        if value.hasPrefix("v") {
            value = String(value.dropFirst())
        }
        return value
    }

    private static func isNewer(_ lhs: String, than rhs: String) -> Bool {
        let left = lhs.split(separator: ".").compactMap { Int($0) }
        let right = rhs.split(separator: ".").compactMap { Int($0) }
        let count = max(left.count, right.count)

        for index in 0..<count {
            let leftValue = index < left.count ? left[index] : 0
            let rightValue = index < right.count ? right[index] : 0
            if leftValue != rightValue {
                return leftValue > rightValue
            }
        }

        return false
    }

    private static func preferredDMGURL(in release: GitHubRelease) -> URL? {
        let dmg = release.assets.first { $0.name.lowercased().hasSuffix(".dmg") }
        return dmg.flatMap { URL(string: $0.browserDownloadURL) }
    }
}

private struct GitHubRelease: Decodable {
    let tagName: String
    let htmlURL: String
    let draft: Bool
    let prerelease: Bool
    let body: String?
    let publishedAt: TimeInterval?
    let assets: [GitHubAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
        case draft, prerelease, body, assets
        case publishedAt = "published_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tagName = try container.decode(String.self, forKey: .tagName)
        htmlURL = try container.decode(String.self, forKey: .htmlURL)
        draft = try container.decode(Bool.self, forKey: .draft)
        prerelease = try container.decode(Bool.self, forKey: .prerelease)
        body = try container.decodeIfPresent(String.self, forKey: .body)
        assets = try container.decodeIfPresent([GitHubAsset].self, forKey: .assets) ?? []

        if let iso8601 = try container.decodeIfPresent(String.self, forKey: .publishedAt) {
            publishedAt = ISO8601DateFormatter().date(from: iso8601)?.timeIntervalSince1970
        } else {
            publishedAt = nil
        }
    }
}

private struct GitHubAsset: Decodable {
    let name: String
    let browserDownloadURL: String

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
    }
}
