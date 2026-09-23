// Tests for the onboarding flow: starting, permissions, the download, finishing, and stray intents.
import Testing

@testable import UttrflowCore
@testable import UttrflowSettings
@testable import UttrflowUX

/// The download failure the tests script, taken from the error so a reworded message is not a failure.
private let downloadFailure = SpeechEngineError.modelDownloadFailed(description: "offline")

@MainActor
@Suite("Onboarding flow")
struct OnboardingFlowTests {

    // MARK: Getting under way

    @Test("opens on the welcome page, with a dot for every page there will be")
    func opensOnWelcome() async {
        // Signed in already, which is what makes welcome the first page anybody sees.
        let harness = Harness()
        await harness.flow.start()

        #expect(harness.step == .welcome)
        #expect(harness.detail == .reading)
        #expect(harness.page.position == OnboardingStep.welcome.position)
        #expect(harness.page.stepCount == OnboardingStep.allCases.count)
        #expect(harness.buttonTitles == ["Continue"])
    }

    /// What the Account page's Sign In reaches; a returning user does not need the pitch again.
    @Test("resuming opens on sign-in rather than on the pitch")
    func resumeSkipsWelcome() async {
        let harness = Harness(microphone: .granted, accessibility: .granted, signedIn: false)
        await harness.flow.resume()

        #expect(harness.step == .signIn)
        #expect(!harness.published.contains { $0.step == .welcome })
    }

    /// Signing back in and finding the app still mute would be worse than one extra page.
    @Test("resuming still walks everything after the pitch, not only sign-in")
    func resumeStillAsksForPermissions() async {
        let harness = Harness(microphone: .notDetermined, accessibility: .granted, signedIn: true)
        await harness.flow.resume()

        #expect(harness.step == .microphone)
    }

    @Test("asks for the microphone before anything else")
    func microphoneComesFirst() async {
        let harness = Harness(microphone: .notDetermined)
        await harness.flow.start()

        #expect(await harness.press("Continue"))
        #expect(harness.step == .microphone)
        #expect(harness.detail == .permission(.notDetermined))
        #expect(harness.buttonTitles == ["Allow Microphone Access", "Continue Without It"])
    }

    // MARK: A permission that is already granted

    @Test("passes over a permission macOS has already granted rather than agreeing with itself")
    func skipsGrantedPermissions() async {
        let harness = Harness(microphone: .granted, accessibility: .granted)
        await harness.flow.start()

        #expect(await harness.press("Continue"))
        #expect(harness.step == .ready)
        #expect(harness.detail == .finishing(.ready))
        #expect(!harness.published.contains { $0.step == .microphone })
        #expect(!harness.published.contains { $0.step == .accessibility })
    }

    @Test("moves on the moment the prompt is answered yes")
    func grantingAtThePromptMovesOn() async {
        let harness = Harness(
            microphone: .notDetermined, microphoneAfterAsking: .granted, accessibility: .granted)
        await harness.flow.start()
        #expect(await harness.press("Continue"))

        #expect(await harness.press("Allow Microphone Access"))
        #expect(harness.step == .ready)
        #expect(harness.detail == .finishing(.ready))
    }

    // MARK: A permission that is refused

    @Test("a no at the prompt turns the page into the way back, not a repeat of the prompt")
    func refusingAtThePromptOffersSystemSettings() async {
        let harness = Harness(microphone: .notDetermined, microphoneAfterAsking: .denied)
        await harness.flow.start()
        #expect(await harness.press("Continue"))

        #expect(await harness.press("Allow Microphone Access"))
        #expect(harness.step == .microphone)
        #expect(harness.detail == .permission(.denied))
        #expect(harness.buttonTitles == ["Open System Settings", "Continue Without It"])
        #expect(harness.page.note != nil)
    }

    @Test("granted in System Settings, and the user comes back")
    func grantedWhileAway() async {
        let harness = Harness(microphone: .notDetermined, microphoneAfterAsking: .denied)
        await harness.flow.start()
        #expect(await harness.press("Continue"))
        #expect(await harness.press("Allow Microphone Access"))

        #expect(await harness.press("Open System Settings"))
        #expect(harness.panes.panes == [.microphone])
        #expect(harness.detail == .awaitingSystemSettings)
        #expect(
            harness.buttonTitles == ["Open System Settings", "Check Again", "Continue Without It"])

        await harness.microphone.setStatus(.granted)
        await harness.flow.refresh()
        #expect(harness.step != .microphone)
    }

    /// Checking again must not loop, and the way on stays beside it however many times it is pressed.
    @Test("still refused on the way back: no loop, and the way on is still there")
    func stillRefusedOnReturn() async {
        let harness = Harness(microphone: .notDetermined, microphoneAfterAsking: .denied)
        await harness.flow.start()
        #expect(await harness.press("Continue"))
        #expect(await harness.press("Allow Microphone Access"))
        #expect(await harness.press("Open System Settings"))

        await harness.flow.refresh()
        #expect(harness.detail == .awaitingSystemSettings)
        #expect(await harness.press("Check Again"))
        #expect(harness.step == .microphone)
        #expect(harness.detail == .awaitingSystemSettings)
        #expect(
            harness.buttonTitles == ["Open System Settings", "Check Again", "Continue Without It"])

        // The pane stays reachable for somebody who closed the wrong window, and does not move them on.
        #expect(await harness.press("Open System Settings"))
        #expect(harness.step == .microphone)
        #expect(harness.panes.panes == [.microphone, .microphone])
    }

    @Test("a permission taken away by policy while the user was out offers what is left")
    func blockedWhileAway() async {
        let harness = Harness(microphone: .notDetermined, microphoneAfterAsking: .denied)
        await harness.flow.start()
        #expect(await harness.press("Continue"))
        #expect(await harness.press("Allow Microphone Access"))
        #expect(await harness.press("Open System Settings"))

        await harness.microphone.setStatus(.restricted)
        await harness.flow.refresh()
        #expect(harness.detail == .permission(.restricted))
        #expect(harness.buttonTitles == ["Continue Without It"])
    }

    @Test("a permission blocked by policy never pretends it can be asked for")
    func restrictedFromTheStart() async {
        let harness = Harness(microphone: .restricted, microphoneAfterAsking: nil)
        await harness.flow.start()

        #expect(await harness.press("Continue"))
        #expect(harness.detail == .permission(.restricted))
        #expect(harness.buttonTitles == ["Continue Without It"])
        #expect(harness.page.subtitle.contains("policy"))
    }

    // MARK: Accessibility, which is the one it is reasonable to do without

    @Test("offers to ask for Accessibility when macOS has not been asked yet")
    func accessibilityCanBeAskedFor() async {
        let harness = Harness(
            microphone: .granted, accessibility: .notDetermined,
            accessibilityAfterAsking: .granted)
        await harness.flow.start()

        #expect(await harness.press("Continue"))
        #expect(harness.step == .accessibility)
        #expect(
            harness.buttonTitles == ["Allow Accessibility Access", "Continue Without It"])
        #expect(await harness.press("Allow Accessibility Access"))
        #expect(harness.detail == .finishing(.ready))
    }

    /// `AXIsProcessTrusted` cannot say "not asked", so the first visit still asks rather than sending them away.
    @Test("sends the user to the Accessibility pane once the ask has been made")
    func accessibilityGoesToItsOwnPane() async {
        let harness = Harness(microphone: .granted, accessibility: .denied)
        await harness.flow.start()
        #expect(await harness.press("Continue"))

        #expect(harness.step == .accessibility)
        #expect(harness.page.note == nil, "nobody has refused anything yet")
        #expect(await harness.press("Allow Accessibility Access"))
        #expect(await harness.press("Open System Settings"))
        #expect(harness.panes.panes == [.accessibility])
    }

    @Test("Accessibility granted in System Settings is noticed on the way back too")
    func accessibilityGrantedWhileAway() async {
        let harness = Harness(microphone: .granted, accessibility: .denied)
        await harness.flow.start()
        #expect(await harness.press("Continue"))
        #expect(harness.step == .accessibility)

        await harness.accessibility.setStatus(.granted)
        await harness.flow.refresh()
        #expect(harness.step == .ready)
        #expect(harness.detail == .finishing(.ready))
    }

    /// Accessibility cannot be skipped, so nothing on the page ends the step without the permission.
    @Test("Accessibility cannot be walked past")
    func accessibilityCannotBeSkipped() async {
        let harness = Harness(microphone: .granted, accessibility: .denied)
        await harness.flow.start()
        #expect(await harness.press("Continue"))
        #expect(harness.step == .accessibility)

        #expect(!(await harness.press("Skip")))
        #expect(!(await harness.press("Not now")))
        #expect(!(await harness.press("Continue")))
        #expect(harness.step == .accessibility)

        // Granting it is the only thing that moves, and it does.
        await harness.accessibility.setStatus(.granted)
        await harness.flow.refresh()
        #expect(harness.step == .ready)
        #expect(harness.detail == .finishing(.ready))
    }

    // MARK: Never claiming something it has not just read

    @Test("re-reads the permissions on the last page rather than trusting the clicks")
    func lastPageRereadsEverything() async {
        let harness = Harness(
            microphone: .notDetermined, microphoneAfterAsking: .granted, accessibility: .granted)
        await harness.flow.start()
        #expect(await harness.press("Continue"))
        #expect(await harness.press("Allow Microphone Access"))
        #expect(harness.detail == .finishing(.ready))

        // The user turns the microphone off again with the last page still open.
        await harness.microphone.setStatus(.denied)
        await harness.flow.refresh()
        #expect(harness.detail == .finishing(.needsMicrophone))
        #expect(harness.buttonTitles == ["Open System Settings", "Close"])
    }

    /// The rule the flow is built on, end to end: a refusal is a choice, not a wall. See `Docs/ux-onboarding.md`.
    @Test("a user who will not grant Accessibility still finishes, and is told what it costs")
    func finishesWithoutAccessibility() async {
        let harness = Harness(microphone: .granted, accessibility: .denied)
        await harness.flow.start()
        #expect(await harness.press("Continue"))
        #expect(harness.step == .accessibility)

        #expect(await harness.press("Continue Without It"))
        #expect(harness.detail == .finishing(.pastesManually))
        #expect(await harness.press("Start Using Uttrflow"))
        #expect(harness.finishedWith == .pastesManually)
    }

    @Test("a user who will not grant the microphone still finishes, and is told what it costs")
    func finishesWithoutTheMicrophone() async {
        let harness = Harness(
            microphone: .notDetermined, microphoneAfterAsking: .denied, accessibility: .granted)
        await harness.flow.start()
        #expect(await harness.press("Continue"))
        #expect(await harness.press("Allow Microphone Access"))
        #expect(harness.detail == .permission(.denied))

        #expect(await harness.press("Continue Without It"))
        #expect(harness.detail == .finishing(.needsMicrophone))
        // Without a microphone there is nothing to start, so the last page closes rather than cheers.
        #expect(await harness.press("Close"))
        #expect(harness.finishedWith == .needsMicrophone)
    }

    /// Refusing both is the same choice twice, and neither page may hold the user on the way through.
    @Test("a user who grants neither permission still reaches the end")
    func finishesWithNeitherPermission() async {
        let harness = Harness(
            microphone: .notDetermined, microphoneAfterAsking: .denied, accessibility: .denied)
        await harness.flow.start()
        #expect(await harness.press("Continue"))
        #expect(await harness.press("Allow Microphone Access"))
        #expect(await harness.press("Continue Without It"))

        // Neither page holds them: the second refusal is left the same way as the first.
        #expect(harness.step == .accessibility)
        #expect(await harness.press("Continue Without It"))

        // The microphone stops them first, so that is the ending the last page reads.
        #expect(harness.detail == .finishing(.needsMicrophone))
        #expect(harness.finishedWith == nil, "nothing is finished until the last page is pressed")
        #expect(await harness.press("Close"))
        #expect(harness.finishedWith == .needsMicrophone)
    }

    /// Going past a refusal must never look like granting it, or the user is told they are set up when they are not.
    @Test("going on without Accessibility does not say the Mac is ready")
    func goingOnIsNotGranting() async {
        let harness = Harness(microphone: .granted, accessibility: .denied)
        await harness.flow.start()
        #expect(await harness.press("Continue"))
        #expect(await harness.press("Continue Without It"))

        #expect(harness.detail != .finishing(.ready))
    }

    // MARK: The download

    @Test("draws the download as it goes, and moves on when it lands")
    func downloadRunsToTheEnd() async {
        let installer = GatedInstaller()
        let harness = Harness(
            microphone: .granted, accessibility: .granted, installer: installer)
        await harness.flow.start()

        let running = Task { await harness.flow.perform(.advance) }
        await settle(until: { installer.startedDownloads == 1 })
        #expect(harness.step == .setup)
        #expect(harness.detail == .installing(0))
        #expect(harness.page.buttons.contains { $0.title == "Continue" && !$0.isEnabled })
        #expect(await harness.press("Continue") == false)

        // Nothing on this page waits on another application, so coming back must not disturb the download.
        await harness.flow.refresh()
        #expect(harness.detail == .installing(0))

        installer.send(.report(0.4))
        await settle(until: { harness.detail == .installing(0.4) })
        #expect(harness.page.progress == 0.4)

        installer.send(.succeed)
        await running.value
        #expect(harness.step == .ready)
        #expect(harness.detail == .finishing(.ready))
    }

    @Test("a download that gives out says so, and can be started again")
    func downloadFailsAndIsRetried() async {
        let installer = GatedInstaller()
        let harness = Harness(
            microphone: .granted, accessibility: .granted, installer: installer)
        await harness.flow.start()

        let running = Task { await harness.flow.perform(.advance) }
        await settle(until: { installer.startedDownloads == 1 })
        installer.send(.fail(downloadFailure))
        await running.value

        #expect(harness.step == .setup)
        #expect(harness.detail == .installFailed(downloadFailure.userMessage))
        #expect(harness.buttonTitles == ["Not now", "Try Again"])

        let retrying = Task { _ = await harness.press("Try Again") }
        await settle(until: { installer.startedDownloads == 2 })
        installer.send(.succeed)
        await retrying.value
        #expect(harness.detail == .finishing(.ready))
    }

    @Test("a download the user gave up on cannot come back and redraw the page")
    func cancellingADownloadIsFinal() async {
        let installer = GatedInstaller()
        let harness = Harness(
            microphone: .granted, accessibility: .granted, installer: installer)
        await harness.flow.start()

        let running = Task { await harness.flow.perform(.advance) }
        await settle(until: { installer.startedDownloads == 1 })
        installer.send(.report(0.4))
        await settle(until: { harness.detail == .installing(0.4) })

        #expect(await harness.press("Cancel"))
        #expect(harness.step == .ready)
        #expect(harness.detail == .finishing(.needsSpeechModel))

        installer.send(.report(0.9))
        await running.value
        #expect(harness.detail == .finishing(.needsSpeechModel))
        #expect(!harness.published.contains { $0.detail == .installing(0.9) })
    }

    @Test("the last page can send the user back to a download they gave up on")
    func lastPageOffersTheDownloadAgain() async {
        let installer = GatedInstaller()
        let harness = Harness(
            microphone: .granted, accessibility: .granted, installer: installer)
        await harness.flow.start()

        let running = Task { await harness.flow.perform(.advance) }
        await settle(until: { installer.startedDownloads == 1 })
        await harness.flow.perform(.cancelInstall)
        await running.value
        #expect(harness.detail == .finishing(.needsSpeechModel))
        #expect(harness.buttonTitles == ["Download Now", "Start Using Uttrflow"])

        let again = Task { _ = await harness.press("Download Now") }
        await settle(until: { installer.startedDownloads == 2 })
        installer.send(.succeed)
        await again.value
        #expect(harness.detail == .finishing(.ready))
    }

    @Test("passes over the download when the model is already there")
    func skipsAnInstalledModel() async {
        let harness = Harness(
            microphone: .granted, accessibility: .granted,
            installer: InstantInstaller(isInstalled: true))
        await harness.flow.start()

        #expect(await harness.press("Continue"))
        #expect(!harness.published.contains { $0.step == .setup })
    }

    // MARK: Finishing, and coming back

    @Test("writes down that it is over, and nothing else")
    func finishingIsTheOnlyThingWrittenDown() async {
        let harness = Harness(microphone: .granted, accessibility: .granted)
        let before = harness.settingsStore.load()
        await harness.flow.start()
        #expect(await harness.press("Continue"))

        #expect(!harness.record.hasFinished)
        #expect(await harness.press("Start Using Uttrflow"))
        #expect(harness.record.hasFinished)
        #expect(harness.settingsStore.load() == before)
        #expect(harness.flow.isFinished)
        #expect(harness.finishedWith == .ready)
    }

    /// The last page is somewhere a settled user stands, and a switch they turned off is not onboarding's.
    @Test("leaves a login preference the user has turned off turned off")
    func finishingNeverRevivesOpeningAtLogin() async {
        // Switch turned off in Settings, then signed out, then Sign In on the Account page to the end.
        let harness = Harness(
            microphone: .granted, accessibility: .granted, settings: Settings(opensAtLogin: false),
            hasFinished: true, signedIn: false)
        await harness.flow.resume()
        #expect(await harness.choose(.google))
        await harness.returnFromBrowser()
        #expect(harness.step == .ready)

        #expect(await harness.press("Start Using Uttrflow"))
        #expect(harness.settingsStore.load().opensAtLogin == false)
    }

    /// Onboarding does not block the app, so Settings can change something while the flow stands there.
    @Test("does not write back the settings it read when it opened")
    func finishingDoesNotRevertAChangeMadeWhileItStood() async {
        let harness = Harness(
            microphone: .granted, accessibility: .granted, hasFinished: true)
        await harness.flow.resume()
        #expect(harness.step == .ready)

        // The Settings window, over the top of the open flow, changes the shortcut.
        let chosen = HotkeyBinding(keyCode: 36, modifiers: [.command, .shift])
        var elsewhere = harness.settingsStore.load()
        elsewhere.hotkey = chosen
        harness.settingsStore.save(elsewhere)

        #expect(await harness.press("Start Using Uttrflow"))
        #expect(harness.settingsStore.load().hotkey == chosen)
    }

    /// Reading a snapshot to draw with is fine; drawing one taken minutes ago is not.
    @Test("shows the shortcut the settings hold now, not the one they held when it opened")
    func lastPageFollowsAShortcutChangedWhileItStood() async {
        let harness = Harness(
            microphone: .granted, accessibility: .granted, hasFinished: true)
        await harness.flow.resume()

        var elsewhere = harness.settingsStore.load()
        elsewhere.hotkey = HotkeyBinding(keyCode: 36, modifiers: [.command, .shift])
        harness.settingsStore.save(elsewhere)
        await harness.flow.refresh()

        #expect(harness.page.keys == ["⇧", "⌘", "Return"])
    }

    @Test("a user who has finished is never onboarded again")
    func finishedUsersAreLeftAlone() {
        #expect(Harness(hasFinished: true).flow.isRequired == false)
        #expect(Harness(hasFinished: false).flow.isRequired)
    }

    @Test("quitting halfway remembers nothing, so nothing already granted is asked twice")
    func quittingHalfwayAsksOnlyWhatIsStillOutstanding() async {
        // First run: the microphone is granted, and the user quits on the next page.
        let first = Harness(
            microphone: .notDetermined, microphoneAfterAsking: .granted, accessibility: .denied)
        await first.flow.start()
        #expect(await first.press("Continue"))
        #expect(await first.press("Allow Microphone Access"))
        #expect(first.step == .accessibility)
        #expect(!first.record.hasFinished)

        // Second run starts from the beginning, but a question macOS has answered is not put again.
        let second = Harness(microphone: .granted, accessibility: .denied)
        #expect(second.flow.isRequired)
        await second.flow.start()
        #expect(second.step == .welcome)
        #expect(await second.press("Continue"))
        #expect(second.step == .accessibility)
    }

    // MARK: Odds and ends

    @Test("leaves the pages that are waiting on nobody alone")
    func refreshingAPageThatWaitsOnNothing() async {
        let harness = Harness()
        await harness.flow.start()
        let published = harness.published.count

        await harness.flow.refresh()
        #expect(harness.step == .welcome)
        #expect(harness.published.count == published)
    }

    @Test("ignores a recovery that belongs to some other part of the app")
    func recoveriesItDoesNotOffer() async {
        let harness = Harness(microphone: .granted, accessibility: .granted)
        await harness.flow.start()
        let before = harness.flow.state

        await harness.flow.perform(.recover(.pasteManually))
        #expect(harness.flow.state == before)
    }

    @Test("ignores instructions that could only have come from a page the user has left")
    func intentsBelongingToOtherPages() async {
        let harness = Harness(microphone: .granted, accessibility: .granted)
        await harness.flow.start()
        #expect(harness.step == .welcome)

        for stray: OnboardingIntent in [.cancelSignIn] {
            await harness.flow.perform(stray)
            #expect(harness.step == .welcome, "\(stray) dragged the user off the page")
        }
    }

    @Test("cannot be closed from a page that has not worked out what it is promising")
    func onlyTheLastPageCanClose() async {
        let harness = Harness(microphone: .granted, accessibility: .granted)
        await harness.flow.start()

        await harness.flow.perform(.finish)
        #expect(!harness.flow.isFinished)
        #expect(!harness.record.hasFinished)
        #expect(harness.finishedWith == nil)
    }

    @Test("shows the shortcut the settings actually hold, not the one it shipped with")
    func lastPageShowsTheChosenShortcut() async {
        let harness = Harness(
            microphone: .granted, accessibility: .granted,
            settings: Settings(
                shortcuts: ShortcutSet([
                    .dictate: [HotkeyBinding(keyCode: 36, modifiers: [.command, .shift])]
                ])))
        await harness.flow.start()

        #expect(await harness.press("Continue"))
        #expect(harness.page.keys == ["⇧", "⌘", "Return"])
    }
}
