import BackgroundAdapters
import Testing

@Test func aGreaterVersionIsNewer() throws {
    let running = try #require(ReleaseVersion("0.2.0"))

    #expect(try #require(ReleaseVersion("0.2.1")) > running)
    #expect(try #require(ReleaseVersion("0.3.0")) > running)
    #expect(try #require(ReleaseVersion("1.0.0")) > running)
}

@Test func anEqualOrLowerVersionIsNotNewer() throws {
    let running = try #require(ReleaseVersion("0.2.0"))

    #expect(!(try #require(ReleaseVersion("0.2.0")) > running))
    #expect(!(try #require(ReleaseVersion("0.1.9")) > running))
}

@Test func componentsCompareNumericallyNotAsText() throws {
    #expect(try #require(ReleaseVersion("0.10.0")) > #require(ReleaseVersion("0.9.0")))
}

@Test func aReleaseTagParsesWithOrWithoutTheLeadingV() {
    #expect(ReleaseVersion(tag: "v0.2.0") == ReleaseVersion("0.2.0"))
    #expect(ReleaseVersion(tag: "0.2.0") == ReleaseVersion("0.2.0"))
}

@Test(arguments: ["", "v", "0.2", "0.2.0.1", "v0.2.x", "0.-1.0", "vv0.2.0", "0.2.0-beta", " 0.2.0", "latest"])
func aTagThatIsNotXYZIsIgnored(tag: String) {
    #expect(ReleaseVersion(tag: tag) == nil)
}

@Test func aVersionPrintsAsXYZ() {
    #expect(ReleaseVersion(tag: "v0.10.3")?.description == "0.10.3")
}
