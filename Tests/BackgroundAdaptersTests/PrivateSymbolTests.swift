import BackgroundAdapters
import Testing

private typealias NoArguments = @convention(c) () -> Int32

@Test func missingSymbolResolvesToNilAndLogsOneLine() {
    var lines: [String] = []

    let function = PrivateSymbol.resolve("DowntabNoSuchSymbol", in: .skyLight, as: NoArguments.self) {
        lines.append($0)
    }

    #expect(function == nil)
    #expect(lines == ["private symbol missing: DowntabNoSuchSymbol, its feature is off"])
}

@Test func presentSymbolResolvesWithoutLogging() {
    var lines: [String] = []

    let function = PrivateSymbol.resolve("getpid", in: .process, as: NoArguments.self) { lines.append($0) }

    #expect(function != nil)
    #expect(lines.isEmpty)
}
