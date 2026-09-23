import AppKit
import SwiftUI
import UttrflowCore
import UttrflowUX

/// Whatever a row asked for, drawn as one switch over a closed set. See `Docs/app-settings-controls.md`.
struct SettingsControlView: View {
    let control: SettingsControl
    let isEnabled: Bool
    /// What the row says this control is for; the control hides its own label, so VoiceOver needs this.
    let label: String
    let model: SettingsViewModel

    var body: some View {
        switch control {
        case .segmented:
            // Each option names itself; one label over the pair reads as two identical buttons.
            view(for: control)
                .accessibilityElement(children: .contain)
                .accessibilityLabel(label)
        default:
            view(for: control).accessibilityLabel(label)
        }
    }

    /// The one control a settings row asked for.
    @ViewBuilder private func view(for control: SettingsControl) -> some View {
        switch control {
        case .toggle(let field, let isOn):
            Toggle(
                "",
                isOn: Binding(
                    get: { isOn },
                    set: { model.apply(.toggle(field, isOn: $0)) })
            )
            .labelsHidden()
            .toggleStyle(SettingsSwitchStyle())

        case .applicationSwitch(let isOn, let change):
            // The same switch as `.toggle`, for a row standing for an application.
            Toggle(
                "",
                isOn: Binding(
                    get: { isOn },
                    set: { _ in model.apply(change) })
            )
            .labelsHidden()
            .toggleStyle(SettingsSwitchStyle())

        case .segmented(let options, let selectedID):
            SettingsSegmented(
                options: options.map { (id: $0.id, title: $0.title) },
                selection: selection(options, selectedID))

        case .menu(let options, let selectedID):
            SettingsMenu(
                options: options.map { (id: $0.id, title: $0.title) },
                selection: selection(options, selectedID))

        case .anchorPicker(let selected):
            SettingsAnchorPicker(selected: selected) { model.apply(.anchor($0)) }

        case .shortcut(let action, let keys):
            SettingsShortcutField(action: action, keys: keys, model: model)

        case .tick(let isTicked, let change):
            Button {
                model.apply(change)
            } label: {
                Image(systemName: isTicked ? "checkmark.square.fill" : "square")
                    .font(.system(size: 15))
                    .foregroundStyle(isTicked ? Color.dockAccent : Color.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isTicked ? [.isButton, .isSelected] : .isButton)

        case .removal(let removal):
            // Red without asking; never the default action, since Return must not remove anything.
            Button(removal.title) { model.request(removal) }
                .buttonStyle(SettingsButtonStyle(isDestructive: true))

        case .action(let title, let change):
            // Not destructive, so not red and not confirmed: both belong to `removal` alone.
            Button(title) { model.apply(change) }
                .buttonStyle(SettingsButtonStyle(isDestructive: false))

        case .text(let value):
            // Selectable, because a version number exists to be quoted into a bug report.
            Text(value)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
    }

    /// A picker's selection; the get answers the presenter's id, so a refused pick snaps back.
    private func selection(
        _ options: [SettingsOption], _ selectedID: String
    ) -> Binding<String> {
        Binding(
            get: { selectedID },
            set: { picked in
                guard let option = options.first(where: { $0.id == picked }) else { return }
                model.apply(option.change)
            })
    }
}

// MARK: - Where the button parks

/// The four corners the floating button can park in, drawn as a small screen.
struct SettingsAnchorPicker: View {
    let selected: DockAnchor
    let onSelect: (DockAnchor) -> Void

    var body: some View {
        ZStack {
            // The screen the button parks on, in this window's own colours.
            RoundedRectangle(cornerRadius: 5)
                .fill(Color.settingsControl)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .strokeBorder(Color.mainSeparator, lineWidth: 1))
            ForEach(DockAnchor.allCases, id: \.self) { anchor in
                dot(anchor)
            }
        }
        .frame(width: 46, height: 29)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Where the floating button parks")
    }

    private func dot(_ anchor: DockAnchor) -> some View {
        let isSelected = anchor == selected
        return Button {
            onSelect(anchor)
        } label: {
            Circle()
                .fill(isSelected ? Color.settingsAccentInk : Color.mainDim)
                .frame(width: 5, height: 5)
                .overlay(
                    Circle().strokeBorder(
                        isSelected ? Color.settingsAccentInk.opacity(0.45) : .clear, lineWidth: 2)
                )
                // A five-point dot is not a target. The hit area is the whole quadrant.
                .padding(6)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment(anchor))
        .padding(5)
        .accessibilityLabel(Self.name(of: anchor))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private func alignment(_ anchor: DockAnchor) -> Alignment {
        switch anchor {
        case .bottomLeft: .bottomLeading
        case .bottomCentre: .bottom
        case .bottomRight: .bottomTrailing
        case .rightEdge: .trailing
        }
    }

    /// Spoken, because a dot in a rectangle says nothing to VoiceOver.
    static func name(of anchor: DockAnchor) -> String {
        switch anchor {
        case .bottomLeft: "Bottom left"
        case .bottomCentre: "Bottom centre"
        case .bottomRight: "Bottom right"
        case .rightEdge: "Right edge"
        }
    }
}

// MARK: - The shortcut

/// The shortcut and the field that records a new one. See `Docs/app-settings-controls.md`.
struct SettingsShortcutField: View {
    let action: ShortcutAction
    let keys: [String]
    let model: SettingsViewModel

    /// Recording belongs to one row, so the others keep showing their keys.
    private var isRecording: Bool {
        model.session.recorder.isRecording && model.session.recorder.action == action
    }

    /// The local monitor that owns candidate keystrokes before the menu or responder chain sees them.
    @State private var monitor: Any?

    var body: some View {
        HStack(spacing: 8) {
            if isRecording {
                Text(model.session.recorder.prompt)
                    .font(.system(size: SettingsMetrics.calloutSize))
                    .foregroundStyle(.secondary)
            } else if keys.isEmpty {
                Text("None")
                    .font(.system(size: SettingsMetrics.calloutSize))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(keys.enumerated()), id: \.offset) { _, key in
                    keycap(key)
                }
            }
            Button(isRecording ? "Cancel" : "Change") {
                if isRecording {
                    model.cancelRecordingShortcut()
                } else {
                    model.beginRecordingShortcut(action)
                }
            }
            .buttonStyle(SettingsButtonStyle())
        }
        .onChange(of: isRecording, initial: true) { _, recording in
            recording ? startListening() : stopListening()
        }
        .onDisappear(perform: stopListening)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(action.rawValue) shortcut, \(keys.joined(separator: " "))")
    }

    /// A key drawn as a key, matching first-run so both windows show the same physical thing.
    private func keycap(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12.5, weight: .semibold))
            .fixedSize()
            .padding(.horizontal, 9)
            .frame(minWidth: 30, minHeight: 26)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.settingsControl)
                    .shadow(color: .black.opacity(0.30), radius: 0, y: 1.5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(Color.mainSeparator, lineWidth: 1))
    }

    private func startListening() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            handle(event)
        }
    }

    private func stopListening() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    private func handle(_ event: NSEvent) -> NSEvent? {
        guard isRecording else { return event }
        switch Self.route(event) {
        case .recordAndConsume(let stroke):
            model.receive(stroke)
            return nil
        case .recordAndPass(let stroke):
            model.receive(stroke)
            return event
        case .pass:
            return event
        }
    }

    static func route(_ event: NSEvent) -> ShortcutRecorderEventRoute {
        switch event.type {
        case .keyDown:
            .recordAndConsume(stroke(from: event, phase: .down))
        case .flagsChanged:
            .recordAndPass(stroke(from: event, phase: .modifiersChanged))
        default:
            .pass
        }
    }

    static func stroke(from event: NSEvent, phase: KeyPhase) -> KeyStroke {
        let modifiers = modifiers(from: event.modifierFlags)
        let isFunctionDown = event.modifierFlags.contains(.function)
        let keyCode = UInt16(event.keyCode)
        return KeyStroke(
            keyCode: keyCode, modifiers: modifiers, isFunctionDown: isFunctionDown, phase: phase,
            isKeyDown: isDown(
                keyCode: keyCode, phase: phase, modifiers: modifiers,
                isFunctionDown: isFunctionDown))
    }

    static func isDown(
        keyCode: UInt16, phase: KeyPhase, modifiers: Set<HotkeyModifier>, isFunctionDown: Bool
    ) -> Bool {
        switch phase {
        case .down: true
        case .up: false
        case .modifiersChanged:
            if keyCode == HotkeyBinding.functionKeyCode {
                isFunctionDown
            } else if let named = HotkeyBinding.modifier(ofKeyCode: keyCode) {
                modifiers.contains(named)
            } else {
                false
            }
        }
    }

    /// Cocoa's flags reduced to the four the product recognises; the rest is window-server noise.
    static func modifiers(from flags: NSEvent.ModifierFlags) -> Set<HotkeyModifier> {
        var modifiers: Set<HotkeyModifier> = []
        if flags.contains(.command) { modifiers.insert(.command) }
        if flags.contains(.option) { modifiers.insert(.option) }
        if flags.contains(.control) { modifiers.insert(.control) }
        if flags.contains(.shift) { modifiers.insert(.shift) }
        return modifiers
    }
}

enum ShortcutRecorderEventRoute: Equatable {
    case recordAndConsume(KeyStroke)
    case recordAndPass(KeyStroke)
    case pass
}
