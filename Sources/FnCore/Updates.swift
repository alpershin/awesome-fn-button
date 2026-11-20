import Foundation
import CryptoKit

public struct AppUpdate: Equatable {
    public let version: String
    public let assetName: String
    public let downloadURL: URL
    let size: Int
    let sha256: String
}

public enum Updates {
    public static let releasesURL = URL(string: "https://github.com/alpershin/awesome-fn-button/releases")!
    private static let latestURL = URL(string: "https://api.github.com/repos/alpershin/awesome-fn-button/releases/latest")!

    public static var architecture: String {
        #if arch(arm64)
        return "arm64"
        #else
        return "x86_64"
        #endif
    }

    public static func check(currentVersion: String, architecture: String = architecture,
                             session: URLSession = .shared) async throws -> AppUpdate? {
        var request = URLRequest(url: latestURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("AwesomeFnButton/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        try validate(response)
        return try availableUpdate(from: data, currentVersion: currentVersion, architecture: architecture)
    }

    public static func download(_ update: AppUpdate, to destination: URL, session: URLSession = .shared) async throws {
        let request = URLRequest(url: update.downloadURL, timeoutInterval: 120)
        let (temporaryURL, response) = try await session.download(for: request)
        defer { try? FileManager.default.removeItem(at: temporaryURL) }
        try validate(response)
        let data = try Data(contentsOf: temporaryURL, options: .mappedIfSafe)
        try verify(data, for: update)
        // Atomic replacement preserves an existing download if saving fails.
        try data.write(to: destination, options: .atomic)
    }

    static func availableUpdate(from data: Data, currentVersion: String, architecture: String) throws -> AppUpdate? {
        let release = try JSONDecoder().decode(Release.self, from: data)
        guard !release.draft, !release.prerelease else { return nil }
        let version = release.tag_name.hasPrefix("v") ? String(release.tag_name.dropFirst()) : release.tag_name
        let latest = try versionComponents(version)
        let current = try versionComponents(currentVersion)
        guard current.lexicographicallyPrecedes(latest) else { return nil }
        let name = "awesome-fn-button-\(version)-\(architecture).dmg"
        guard let asset = release.assets.first(where: { $0.name == name }),
              asset.size > 0,
              asset.browser_download_url.absoluteString == "https://github.com/alpershin/awesome-fn-button/releases/download/\(release.tag_name)/\(name)",
              let digest = asset.digest, digest.hasPrefix("sha256:") else {
            throw FnError.message("This release has no verified installer for this Mac. Check Releases on GitHub.")
        }
        let hash = String(digest.dropFirst(7)).lowercased()
        guard hash.count == 64, hash.allSatisfy({ "0123456789abcdef".contains($0) }) else {
            throw FnError.message("The release has an invalid download checksum. Check Releases on GitHub.")
        }
        return AppUpdate(version: version, assetName: name, downloadURL: asset.browser_download_url,
                         size: asset.size, sha256: hash)
    }

    static func verify(_ data: Data, for update: AppUpdate) throws {
        let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard data.count == update.size, hash == update.sha256 else {
            throw FnError.message("The downloaded installer failed verification. It has not been saved or opened. Try downloading again.")
        }
    }

    private static func versionComponents(_ version: String) throws -> [Int] {
        let parts = version.split(separator: ".", omittingEmptySubsequences: false)
        let numbers = parts.compactMap { part -> Int? in
            guard !part.isEmpty, part.allSatisfy({ "0123456789".contains($0) }) else { return nil }
            return Int(part)
        }
        guard parts.count == 3, numbers.count == 3 else {
            throw FnError.message("The release uses an unsupported version format. Check Releases on GitHub.")
        }
        return numbers
    }

    private static func validate(_ response: URLResponse) throws {
        guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
            let status = (response as? HTTPURLResponse)?.statusCode
            if status == 403 || status == 429 {
                throw FnError.message("GitHub is limiting update requests. Try again later or open Releases on GitHub.")
            }
            throw FnError.message("GitHub could not complete the request\(status.map { " (HTTP \($0))" } ?? ""). Try again later.")
        }
    }

    private struct Release: Decodable {
        let tag_name: String
        let draft: Bool
        let prerelease: Bool
        let assets: [Asset]
    }

    private struct Asset: Decodable {
        let name: String
        let browser_download_url: URL
        let size: Int
        let digest: String?
    }
}
