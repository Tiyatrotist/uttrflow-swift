// That Edit ▸ Find reaches the page's search field, and is offered only where there is one.

import AppKit
import Foundation
import Testing
import UttrflowUX

@testable import Uttrflow

/// The stored property named `label`, read by reflection because the controller keeps it private.
private func stored<T>(_ label: String, of subject: Any, as type: T.Type) -> T? {
    Mirror(reflecting: subject).descendant(label) as? T
}

/// The same page with its search field showing, which is the only state Find is offered on.
private func searchable(_ history: HistoryPresentation) -> HistoryPresentation {
    HistoryPresentation(
        days: history.days, emptyState: history.emptyState,
        retentionNotice: history.retentionNotice, showsSearch: true)
}

@MainActor
@Suite("Edit ▸ Find", .timeLimit(.minutes(1)), .serialized)
struct FindCommandTests {
    /// The app's real window over a sandbox, held by the app as opening a window holds it.
    private func opened(in root: URL) throws -> (
        AppDelegate, MainWindowController, MainWindowModel
    ) {
        let app = AppDelegate(container: root)
        let controller = app.makeMainWindow()
        app.mainWindow = controller
        let model = try #require(stored("model", of: controller, as: MainWindowModel.self))
        model.content.history = searchable(model.content.history)
        return (app, controller, model)
    }

    @Test("is offered on a page whose search field is showing")
    func offeredWhereThereIsAFieldToReach() throws {
        let sandbox = Sandbox()
        let (_, controller, _) = try opened(in: sandbox.root)
        controller.show(.history)

        #expect(controller.canFocusSearch)
    }

    @Test("is withheld on a page that has no search field")
    func withheldWhereThereIsNone() throws {
        let sandbox = Sandbox()
        let (_, controller, _) = try opened(in: sandbox.root)
        controller.show(.home)

        #expect(!controller.canFocusSearch)
    }

    /// Off screen there is no caret to move, so the item is grey rather than silently doing nothing.
    @Test("is withheld while the window is not on screen")
    func withheldWithNoWindowOnScreen() throws {
        let sandbox = Sandbox()
        let (_, controller, _) = try opened(in: sandbox.root)
        controller.show(.history)
        controller.hide()

        #expect(!controller.canFocusSearch)
    }

    @Test("the menu item is grey until a page with a search field is on screen")
    func validationFollowsThePage() throws {
        let sandbox = Sandbox()
        let (app, controller, _) = try opened(in: sandbox.root)
        let item = try #require(MainMenu.edit.items.first { $0.title == "Find" })

        controller.show(.home)
        #expect(!app.validateMenuItem(item))
        controller.show(.history)
        #expect(app.validateMenuItem(item))
    }

    /// The sidebar item still names itself, so the switch added for Find did not take that over.
    @Test("validating Find leaves the sidebar item's own title alone")
    func validationStillNamesTheSidebarItem() throws {
        let sandbox = Sandbox()
        let (app, controller, _) = try opened(in: sandbox.root)
        let toggle = try #require(MainMenu.view.items.first { !$0.isSeparatorItem })
        controller.show(.history)

        #expect(app.validateMenuItem(toggle))
        #expect(toggle.title == (controller.isSidebarExpanded ? "Hide Sidebar" : "Show Sidebar"))
    }

    @Test("choosing it asks the page's search field for the caret")
    func choosingItAsksForTheCaret() throws {
        let sandbox = Sandbox()
        let (app, controller, model) = try opened(in: sandbox.root)
        controller.show(.history)
        let before = model.searchFocusRequest

        app.findFromMenu(nil)

        #expect(model.searchFocusRequest == before + 1)
    }

    /// Nothing to focus means nothing asked for, so a stale request cannot fire on the next page.
    @Test("choosing it on a page with no search field asks for nothing")
    func choosingItWithNoFieldAsksForNothing() throws {
        let sandbox = Sandbox()
        let (app, controller, model) = try opened(in: sandbox.root)
        controller.show(.home)
        let before = model.searchFocusRequest

        app.findFromMenu(nil)

        #expect(model.searchFocusRequest == before)
    }
}
