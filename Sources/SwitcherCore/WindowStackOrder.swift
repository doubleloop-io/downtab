extension [DesktopWindow] {
    /// Ranks are positions among on-screen windows, front to back. Windows with no rank (other Spaces, minimized,
    /// not known to the window server) follow the ranked ones and keep their relative order.
    public func orderedFrontToBack(onScreenRanks ranks: [WindowID: Int]) -> [DesktopWindow] {
        enumerated()
            .sorted { lhs, rhs in
                let lhsRank = lhs.element.id.flatMap { ranks[$0] } ?? Int.max
                let rhsRank = rhs.element.id.flatMap { ranks[$0] } ?? Int.max
                return (lhsRank, lhs.offset) < (rhsRank, rhs.offset)
            }
            .map(\.element)
    }
}
