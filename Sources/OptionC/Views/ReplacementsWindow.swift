import SwiftUI

struct ReplacementsWindow: View {
    @ObservedObject var manager = TextReplacementManager.shared

    @State private var newFind = ""
    @State private var newReplace = ""

    var body: some View {
        VStack(spacing: 0) {
            // Add new replacement
            HStack(spacing: 8) {
                TextField("Find...", text: $newFind)
                    .textFieldStyle(.roundedBorder)
                Image(systemName: "arrow.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
                TextField("Replace with...", text: $newReplace)
                    .textFieldStyle(.roundedBorder)
                Button("Add") {
                    let find = newFind.trimmingCharacters(in: .whitespaces)
                    let replace = newReplace.trimmingCharacters(in: .whitespaces)
                    guard !find.isEmpty else { return }
                    manager.add(find: find, replace: replace)
                    newFind = ""
                    newReplace = ""
                }
                .disabled(newFind.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()

            Divider()

            // List of replacements
            if manager.replacements.isEmpty {
                Spacer()
                Text("No replacements yet.\nAdd phrases above to auto-correct transcriptions.")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
                Spacer()
            } else {
                List {
                    ForEach(manager.replacements) { item in
                        HStack {
                            Text(item.find)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Image(systemName: "arrow.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                            Text(item.replace.isEmpty ? "(remove)" : item.replace)
                                .fontWeight(.medium)
                                .foregroundColor(item.replace.isEmpty ? .secondary : .primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .onDelete { offsets in
                        manager.remove(at: offsets)
                    }
                }
            }
        }
        .frame(width: 450, height: 300)
    }
}

/// Manages opening the replacements window as a proper NSWindow.
@MainActor
final class ReplacementsWindowController {
    static let shared = ReplacementsWindowController()

    private var window: NSWindow?

    func show() {
        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 300),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.title = "Text Replacements"
        panel.isReleasedWhenClosed = false
        panel.contentView = NSHostingView(rootView: ReplacementsWindow())
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        panel.level = .floating
        NSApp.activate(ignoringOtherApps: true)

        window = panel
    }
}
