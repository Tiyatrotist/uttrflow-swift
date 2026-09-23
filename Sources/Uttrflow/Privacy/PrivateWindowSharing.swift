// Keeps windows with user text out of capture clients that honour AppKit's sharing policy.

import AppKit

enum PrivateWindowSharing {
    @MainActor
    static func apply(to window: NSWindow) {
        window.sharingType = .none
    }
}
