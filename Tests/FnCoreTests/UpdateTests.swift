import XCTest
import CryptoKit
@testable import FnCore

private final class UpdateURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (Int, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let (status, data) = try Self.handler!(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    override func stopLoading() {}
}

final class UpdateTests: XCTestCase {
    private let installer = Data("test disk image".utf8)

    private func release(version: String = "0.2.1", arch: String = "arm64", draft: Bool = false,
                         prerelease: Bool = false, url: String? = nil, digest: String? = nil) throws -> Data {
        let name = "awesome-fn-button-\(version)-\(arch).dmg"
        let hash = SHA256.hash(data: installer).map { String(format: "%02x", $0) }.joined()
        return try JSONSerialization.data(withJSONObject: [
            "tag_name": "v\(version)", "draft": draft, "prerelease": prerelease,
            "assets": [["name": name, "size": installer.count,
                        "browser_download_url": url ?? "https://github.com/alpershin/awesome-fn-button/releases/download/v\(version)/\(name)",
                        "digest": digest ?? "sha256:\(hash)"]]
        ])
    }

    func testComparesVersionNumbersAndNeverOffersADowngrade() throws {
        let data = try release(version: "0.2.10")
        XCTAssertEqual(try Updates.availableUpdate(from: data, currentVersion: "0.2.9", architecture: "arm64")?.version, "0.2.10")
        XCTAssertNil(try Updates.availableUpdate(from: data, currentVersion: "0.2.10", architecture: "arm64"))
        XCTAssertNil(try Updates.availableUpdate(from: data, currentVersion: "0.3.0", architecture: "arm64"))
    }

    func testIgnoresDraftsAndPrereleasesAndRequiresMatchingArchitecture() throws {
        XCTAssertNil(try Updates.availableUpdate(from: release(draft: true), currentVersion: "0.2.0", architecture: "arm64"))
        XCTAssertNil(try Updates.availableUpdate(from: release(prerelease: true), currentVersion: "0.2.0", architecture: "arm64"))
        XCTAssertThrowsError(try Updates.availableUpdate(from: release(), currentVersion: "0.2.0", architecture: "x86_64"))
        XCTAssertEqual(try Updates.availableUpdate(from: release(arch: "x86_64"), currentVersion: "0.2.0", architecture: "x86_64")?.assetName,
                       "awesome-fn-button-0.2.1-x86_64.dmg")
    }

    func testRejectsUnofficialDownloadsAndMissingOrMalformedHashes() throws {
        for url in ["http://github.com/alpershin/awesome-fn-button/releases/download/v0.2.1/file.dmg",
                    "https://example.com/update.dmg",
                    "https://github.com/someone/another-app/releases/download/v0.2.1/file.dmg"] {
            XCTAssertThrowsError(try Updates.availableUpdate(from: release(url: url), currentVersion: "0.2.0", architecture: "arm64"))
        }
        for digest in ["", "md5:123", "sha256:123", "sha256:" + String(repeating: "z", count: 64)] {
            XCTAssertThrowsError(try Updates.availableUpdate(from: release(digest: digest), currentVersion: "0.2.0", architecture: "arm64"))
        }
        var missingHash = try JSONSerialization.jsonObject(with: release()) as! [String: Any]
        var assets = missingHash["assets"] as! [[String: Any]]
        assets[0].removeValue(forKey: "digest")
        missingHash["assets"] = assets
        XCTAssertThrowsError(try Updates.availableUpdate(from: JSONSerialization.data(withJSONObject: missingHash),
                                                       currentVersion: "0.2.0", architecture: "arm64"))
    }

    func testRejectsMalformedVersionsAndReleaseResponses() throws {
        for version in ["", "0.2", "0.2.1-beta", "0..1", "-1.2.3", "a.2.3", "0.2.1.4"] {
            XCTAssertThrowsError(try Updates.availableUpdate(from: release(version: version), currentVersion: "0.2.0", architecture: "arm64"))
        }
        XCTAssertThrowsError(try Updates.availableUpdate(from: Data("not JSON".utf8), currentVersion: "0.2.0", architecture: "arm64"))
    }

    func testChecksSizeAndChecksumBeforeAcceptingInstaller() throws {
        let update = try XCTUnwrap(Updates.availableUpdate(from: release(), currentVersion: "0.2.0", architecture: "arm64"))
        XCTAssertNoThrow(try Updates.verify(installer, for: update))
        XCTAssertThrowsError(try Updates.verify(Data(repeating: 0, count: installer.count), for: update))
        XCTAssertThrowsError(try Updates.verify(installer + Data([0]), for: update))
    }

    func testUsesPublicLatestReleaseEndpointAndReportsNetworkAndRateLimitErrors() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [UpdateURLProtocol.self]
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel(); UpdateURLProtocol.handler = nil }
        let data = try release()
        UpdateURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.absoluteString, "https://api.github.com/repos/alpershin/awesome-fn-button/releases/latest")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/vnd.github+json")
            XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
            return (200, data)
        }
        let update = try await Updates.check(currentVersion: "0.2.0", architecture: "arm64", session: session)
        XCTAssertEqual(update?.version, "0.2.1")
        for status in [403, 429, 500] {
            UpdateURLProtocol.handler = { _ in (status, Data()) }
            do {
                _ = try await Updates.check(currentVersion: "0.2.0", session: session)
                XCTFail("HTTP \(status) should fail")
            } catch {
                XCTAssertTrue(error.localizedDescription.contains(status == 500 ? "HTTP 500" : "limiting"))
            }
        }
        UpdateURLProtocol.handler = { _ in throw URLError(.notConnectedToInternet) }
        do {
            _ = try await Updates.check(currentVersion: "0.2.0", session: session)
            XCTFail("An offline request should fail")
        } catch {
            XCTAssertEqual((error as? URLError)?.code, .notConnectedToInternet)
        }
    }
}
