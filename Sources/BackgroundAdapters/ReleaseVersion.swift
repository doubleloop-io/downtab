/// A release's `X.Y.Z` version, ordered numerically per component: `0.10.0` follows `0.9.0`.
public struct ReleaseVersion: Comparable, Sendable, CustomStringConvertible {
    private let components: [Int]

    /// Exactly three dot-separated runs of digits; anything else is not a release version.
    public init?(_ text: String) {
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3 else { return nil }
        var components: [Int] = []
        for part in parts {
            guard part.allSatisfy(\.isASCIIDigit), let number = Int(part) else { return nil }
            components.append(number)
        }
        self.components = components
    }

    /// A git tag such as `v0.2.0`: the leading `v` is optional.
    public init?(tag: String) {
        self.init(tag.hasPrefix("v") ? String(tag.dropFirst()) : tag)
    }

    public var description: String {
        components.map(String.init).joined(separator: ".")
    }

    public static func < (lhs: ReleaseVersion, rhs: ReleaseVersion) -> Bool {
        lhs.components.lexicographicallyPrecedes(rhs.components)
    }
}

extension Character {
    fileprivate var isASCIIDigit: Bool { isASCII && isWholeNumber }
}
