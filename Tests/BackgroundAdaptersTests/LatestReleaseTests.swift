import BackgroundAdapters
import Foundation
import Testing

/// `GET /repos/doubleloop-io/downtab/releases/latest`, recorded; `assets`, `author` and `body` left out.
private let recordedResponse = """
    {
      "url": "https://api.github.com/repos/doubleloop-io/downtab/releases/439054550",
      "html_url": "https://github.com/doubleloop-io/downtab/releases/tag/v0.2.0",
      "id": 439054550,
      "node_id": "RE_kwDOVgeAt84aK3DW",
      "tag_name": "v0.2.0",
      "target_commitish": "main",
      "name": "Downtab 0.2.0",
      "draft": false,
      "immutable": false,
      "prerelease": false,
      "created_at": "2026-11-09T11:34:06Z",
      "published_at": "2026-11-09T11:34:11Z",
      "tarball_url": "https://api.github.com/repos/doubleloop-io/downtab/tarball/v0.2.0",
      "zipball_url": "https://api.github.com/repos/doubleloop-io/downtab/zipball/v0.2.0"
    }
    """

@Test func theRecordedResponseDecodesToItsTagVersion() throws {
    let version = try LatestRelease.version(from: Data(recordedResponse.utf8))

    #expect(version == ReleaseVersion("0.2.0"))
}

@Test func aTagThatIsNotXYZDecodesToNoVersion() throws {
    let body = #"{"tag_name": "nightly", "html_url": "https://github.com/x/y/releases/tag/nightly"}"#

    #expect(try LatestRelease.version(from: Data(body.utf8)) == nil)
}

@Test(arguments: ["", "not json", "{", #"{"html_url": "https://github.com"}"#, #"{"tag_name": 2}"#, "[]"])
func aMalformedResponseFailsToDecode(body: String) {
    #expect(throws: (any Error).self) { try LatestRelease.version(from: Data(body.utf8)) }
}
