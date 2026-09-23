// Which of the panel's keys belong to an input method while it is still composing a word.

/// The keys an input method owns mid-composition, which the panel must not take from it. See `Docs/panel.md`.
public enum PanelComposition {
    /// Whether the panel may act on a key, which it may not while a composition is open.
    public static func panelMayTake(_ key: PanelKey, whileComposing isComposing: Bool) -> Bool {
        guard isComposing else { return true }
        switch key {
        // Return commits the candidate, the arrows walk the candidate list, and Escape cancels the word.
        case .return, .returnPlain, .up, .down, .escape: return false
        // Everything else is the panel's: a chip, a collection number, or the text the field has committed.
        default: return true
        }
    }
}
