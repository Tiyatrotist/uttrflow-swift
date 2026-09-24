// Tests that the emitted development bundle picks the in-memory account backend.

import Foundation
import Testing

import UttrflowAccount

@testable import Uttrflow

/// Mirrors `Scripts/bundle.sh development`'s Info.plist transformation.
@Suite("Development bundle account selection")
struct OnboardingAccountLayerBuildTests {
    /// The shipped Info.plist as a dictionary.
    private func shippedInfo() throws -> [String: Any] {
        let plist = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // UttrflowTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // package root
            .appending(path: "Resources/Uttrflow-Info.plist")
        let data = try Data(contentsOf: plist)
        return try #require(
            try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
    }

    /// A throwaway bundle whose Info.plist has had exactly the keys `bundle.sh development` removes.
    private func developmentBundle() throws -> Bundle {
        var info = try shippedInfo()
        info["CFBundleIdentifier"] = "com.uttrflow.Uttrflow.dev"
        info["CFBundleName"] = "Uttrflow Dev"
        for key in ["SUFeedURL", "SUPublicEDKey", "SUEnableAutomaticChecks", "UttrflowBackendURL"] {
            info.removeValue(forKey: key)
        }

        let root = FileManager.default.temporaryDirectory
            .appending(path: "OnboardingAccountLayerBuildTests-\(UUID().uuidString).bundle")
        let contents = root.appending(path: "Contents")
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        let data = try PropertyListSerialization.data(
            fromPropertyList: info, format: .xml, options: 0)
        try data.write(to: contents.appending(path: "Info.plist"))
        return try #require(Bundle(url: root))
    }

    @Test("the bundle bundle.sh development produces has no backend URL to sign in against")
    func developmentBundleHasNoBackendURL() throws {
        let bundle = try developmentBundle()
        #expect(bundle.object(forInfoDictionaryKey: OnboardingAccountLayer.endpointKey) == nil)
    }

    @Test("forThisBuild selects the in-memory account service for that bundle")
    func developmentBundleUsesInMemoryAccount() throws {
        let layer = OnboardingAccountLayer.forThisBuild(bundle: try developmentBundle())
        #expect(layer.authentication is InMemoryAuthenticationService)
    }
}
