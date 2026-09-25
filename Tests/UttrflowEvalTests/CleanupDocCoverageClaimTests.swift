import Foundation
import Testing

/// Keeps `Docs/cleanup.md`'s sequence-list and paragraph-break coverage claim honest against the rules suite.
@Suite("The cleanup doc's coverage claim matches the rules suite")
struct CleanupDocCoverageClaimTests {
    /// The case IDs `Docs/cleanup.md` names outright as covering paragraph breaks and one numbered list.
    static let namedCases: Set<String> = [
        "new-paragraph", "full-stop-new-paragraph", "email-two-paragraphs",
        "document-numbered-items-after-a-sentence",
    ]

    /// The prefix `Docs/cleanup.md` uses to describe the rest of the numbered-list matrix by shape, not by name.
    static let numberedItemsPrefix = "numbered-items-"

    /// `Docs/cleanup.md`, read from disk so the claim is checked against the file a reader sees.
    private static func cleanupDocText() throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent("Docs/cleanup.md"), encoding: .utf8)
    }

    @Test("every case ID named outright appears in the doc")
    func namedCasesAreInTheDoc() throws {
        let text = try Self.cleanupDocText()
        for id in Self.namedCases {
            #expect(text.contains(id), "\(id) is claimed as covered but is not named in Docs/cleanup.md")
        }
    }

    @Test("every case ID named outright is one RulesCorpusTests requires the rules to pass")
    func namedCasesAreRuleAnswerable() {
        for id in Self.namedCases {
            #expect(
                RulesCorpusTests.rulesMustPass.contains(id),
                "\(id) is claimed in Docs/cleanup.md as rule-covered but is not in RulesCorpusTests.rulesMustPass"
            )
        }
    }

    @Test("the doc's ten-case count for the numbered-items matrix still matches the suite")
    func numberedItemsMatrixCountMatches() throws {
        let text = try Self.cleanupDocText()
        #expect(
            text.contains("ten-case `\(Self.numberedItemsPrefix)*`"),
            "the doc's wildcard claim moved or was reworded")
        let matrixCount = RulesCorpusTests.rulesMustPass.count { $0.hasPrefix(Self.numberedItemsPrefix) }
        #expect(
            matrixCount == 10,
            "RulesCorpusTests has \(matrixCount) '\(Self.numberedItemsPrefix)*' cases, not the ten Docs/cleanup.md claims"
        )
    }
}
