import Foundation

/// Whether the caret sits inside a prose comment rather than executable code. See `Docs/cleanup-design.md`.
public enum CodeCommentContext {
    /// Whether the caret's own line opens a line comment, or an earlier block/doc comment is still unclosed.
    public static func isComment(precedingText: String?, documentName: String?) -> Bool {
        guard let precedingText, let markers = markers(for: documentName) else { return false }
        return isOnCommentLine(precedingText, linePrefixes: markers.line)
            || isInsideOpenBlockComment(precedingText, block: markers.block)
    }

    private struct Markers {
        let line: [String]
        let block: (open: String, close: String)?
    }

    /// The caret's own line, leading whitespace dropped, opens with a line-comment marker for this language.
    private static func isOnCommentLine(_ precedingText: String, linePrefixes: [String]) -> Bool {
        let line =
            precedingText.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).last ?? ""
        let trimmed = line.drop(while: \.isWhitespace)
        return linePrefixes.contains { trimmed.hasPrefix($0) }
    }

    /// The last block-comment opener before the caret has no closer after it, so the caret still sits inside it.
    private static func isInsideOpenBlockComment(
        _ precedingText: String, block: (open: String, close: String)?
    ) -> Bool {
        guard let block, let openRange = precedingText.range(of: block.open, options: .backwards) else {
            return false
        }
        return precedingText.range(of: block.close, range: openRange.upperBound..<precedingText.endIndex)
            == nil
    }

    /// The comment markers for a document's language, or `nil` for an unrecognised or untitled document.
    private static func markers(for documentName: String?) -> Markers? {
        guard let ext = fileExtension(from: documentName) else { return nil }
        switch ext {
        case "swift", "js", "jsx", "mjs", "cjs", "ts", "tsx", "java", "kt", "kts",
            "c", "h", "cc", "cpp", "cxx", "hpp", "m", "mm", "go", "rs", "cs", "php", "scala", "dart":
            return Markers(line: ["//"], block: ("/*", "*/"))
        case "py", "rb", "sh", "bash", "zsh", "fish", "yaml", "yml", "pl", "r":
            return Markers(line: ["#"], block: nil)
        case "sql":
            return Markers(line: ["--"], block: ("/*", "*/"))
        case "lua":
            return Markers(line: ["--"], block: ("--[[", "]]"))
        case "html", "htm", "xml":
            return Markers(line: [], block: ("<!--", "-->"))
        case "css", "scss", "less":
            return Markers(line: [], block: ("/*", "*/"))
        default:
            return nil
        }
    }

    /// The extension of the first filename-shaped token in a document name, which may carry a window title after it.
    private static func fileExtension(from documentName: String?) -> String? {
        guard let documentName else { return nil }
        for token in documentName.split(separator: " ") where token.contains(".") {
            guard let ext = token.split(separator: ".").last, !ext.isEmpty else { continue }
            return String(ext).lowercased()
        }
        return nil
    }
}
