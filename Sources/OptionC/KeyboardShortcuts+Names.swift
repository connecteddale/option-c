import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    // Using Control+Shift+Space - intuitive "press to talk" shortcut
    static let toggleRecording = Self("toggleRecording", default: .init(.space, modifiers: [.control, .shift]))
}
