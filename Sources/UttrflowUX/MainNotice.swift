// What the main window says when a change it was asked to make was refused.
import UttrflowCore

/// A refused change, said where the user pressed; the window carries the latest one only.
public struct MainNotice: Sendable, Equatable {
    /// The failure's own sentence, so the page and the log cannot word one refusal two ways.
    public let message: String
    /// The SF Symbol beside the sentence.
    public let symbolName: String
    /// How it is tinted.
    public let tone: MainTone

    /// Builds a notice from its parts.
    public init(message: String, symbolName: String, tone: MainTone) {
        self.message = message
        self.symbolName = symbolName
        self.tone = tone
    }
}

extension MainNotice {
    /// What an error nobody foresaw says, so a type name never reaches the screen.
    public static let unforeseenMessage = "Something went wrong. Please try again."

    /// The notice for a refused change, from the failure's own sentence and what it cost the user.
    public init(refusing error: any Error) {
        let failure = error as? any UttrflowFailure
        // Recoverable rather than a fault, as ``DictationFailure`` reads an unforeseen error.
        let drawing = Self.drawing(for: failure?.severity ?? .recoverable)
        self.init(
            message: failure?.userMessage ?? Self.unforeseenMessage,
            symbolName: drawing.symbolName,
            tone: drawing.tone)
    }

    /// How loudly a refusal is drawn, from what it cost the user alone.
    static func drawing(for severity: FailureSeverity) -> (symbolName: String, tone: MainTone) {
        switch severity {
        case .blocking, .degraded: ("exclamationmark.triangle", .critical)
        case .recoverable: ("arrow.clockwise", .warning)
        case .informational: ("info.circle", .neutral)
        }
    }
}
