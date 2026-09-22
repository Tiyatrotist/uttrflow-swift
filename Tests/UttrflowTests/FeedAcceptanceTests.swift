// Tests the runtime URL predicate that decides whether the configured feed may be reached.

import Foundation
import Testing

@testable import Uttrflow

/// The runtime gate decides whether Sparkle may talk to the URL in SUFeedURL.
@Suite("The runtime feed gate")
struct FeedAcceptanceTests {
    /// The set of URLs the gate must accept: https to a remote host, and http to the three loopback spellings.
    @Test(
        "accepts https and the three loopback spellings",
        arguments: [
            "https://example.com/appcast.xml",
            "http://127.0.0.1:8080/appcast.xml",
            "http://localhost/appcast.xml",
            "http://[::1]/appcast.xml",
        ]
    )
    func acceptsAllowed(url: String) throws {
        let parsed = try #require(URL(string: url))
        #expect(UpdateController.isAcceptable(parsed), "expected \(url) to be accepted")
    }

    /// The set of URLs the gate must refuse: remote lookalikes with a loopback prefix, plain http to a remote host, and a malformed feed.
    @Test(
        "refuses http lookalikes and any non-https remote host",
        arguments: [
            "http://127.0.0.1.example.com/appcast.xml",
            "http://localhost.example.com/appcast.xml",
            "http://example.com/appcast.xml",
            "ftp://example.com/appcast.xml",
        ]
    )
    func refusesForbidden(url: String) throws {
        let parsed = try #require(URL(string: url))
        #expect(!UpdateController.isAcceptable(parsed), "expected \(url) to be refused")
    }
}
