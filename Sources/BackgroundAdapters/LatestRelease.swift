public import Foundation
import os

/// The latest published release of Downtab on GitHub; drafts and pre-releases are never "latest".
public enum LatestRelease {
    private static let endpoint = URL(string: "https://api.github.com/repos/doubleloop-io/downtab/releases/latest")
    private static let logger = Logger(subsystem: "io.doubleloop.downtab", category: "update")

    private struct Response: Decodable {
        let tagName: String

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
        }
    }

    /// Throws on a body that is not the expected JSON; `nil` when the tag is not an `X.Y.Z` version.
    public static func version(from body: Data) throws -> ReleaseVersion? {
        ReleaseVersion(tag: try JSONDecoder().decode(Response.self, from: body).tagName)
    }

    /// Unauthenticated, so GitHub allows 60 requests per hour per IP.
    /// `nil` when nothing was learned: offline, timeout, non-2xx, rate limit, malformed body or tag. Each is logged.
    public static func fetch() async -> ReleaseVersion? {
        guard let endpoint else { return nil }
        var request = URLRequest(url: endpoint, timeoutInterval: 30)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        logger.notice("checking \(endpoint.absoluteString, privacy: .public)")
        do {
            let (body, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard (200..<300).contains(status) else {
                logger.error("update check failed: HTTP \(status)")
                return nil
            }
            guard let version = try version(from: body) else {
                logger.error("update check ignored a latest release whose tag is not X.Y.Z")
                return nil
            }
            logger.notice("latest release is \(version.description, privacy: .public)")
            return version
        } catch {
            logger.error("update check failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}
