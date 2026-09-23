// Tests which update feeds this build will trust.
import Foundation
import Testing

@testable import UttrflowUX

/// This rule decides where an update may come from, so a feed it wrongly accepts is one Sparkle will read.
@Suite("The feed an updater may read")
struct UpdateFeedTests {
    private func accepts(_ text: String) -> Bool {
        guard let url = URL(string: text) else { return false }
        return UpdateFeed.isAcceptable(url)
    }

    @Test(
        "accepts https anywhere, and plain http only to this Mac",
        arguments: [
            "https://example.com/appcast.xml",
            "http://127.0.0.1:8080/a.xml",
            "http://localhost/a.xml",
            "http://[::1]/a.xml",
        ])
    func accepted(_ feed: String) {
        #expect(accepts(feed))
    }

    /// A rehearsal feed is the only reason plain http exists here; every other one is somebody else's server.
    @Test(
        "refuses plain http anywhere else, and every scheme that is neither",
        arguments: [
            "http://example.com/a.xml",
            "http://127.0.0.1.example.com/a.xml",
            "http://localhost.example.com/a.xml",
            "http://localhost@example.com/a.xml",
            "ftp://127.0.0.1/a.xml",
            "file:///tmp/a.xml",
        ])
    func refused(_ feed: String) {
        #expect(!accepts(feed))
    }

    /// A host in the user part is not the host, which is the oldest way of dressing a URL up as another.
    @Test("reads the host, not a name put before the @")
    func theHostIsNotTheUser() throws {
        let url = try #require(URL(string: "http://localhost@example.com/a.xml"))

        #expect(url.host == "example.com")
        #expect(!UpdateFeed.isAcceptable(url))
    }

    /// A scheme and a host are case-insensitive, so a feed written in capitals is the same feed.
    @Test(
        "reads a scheme and a host whatever their case",
        arguments: ["HTTPS://example.com/a.xml", "HTTP://LOCALHOST/a.xml", "http://LocalHost/a.xml"])
    func caseIsNotPartOfTheRule(_ feed: String) {
        #expect(accepts(feed))
    }

    @Test("refuses a URL with no scheme at all")
    func noScheme() {
        #expect(!accepts("//127.0.0.1/a.xml"))
        #expect(!accepts("appcast.xml"))
    }
}
