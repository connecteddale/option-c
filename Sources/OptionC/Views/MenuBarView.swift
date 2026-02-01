import SwiftUI

struct MenuBarView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Status indicator
            HStack {
                Image(systemName: appState.menuBarIcon)
                Text(appState.currentState.displayName)
            }
            .font(.headline)

            Divider()

            // Recording mode section
            Text("Recording Mode")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Picker("", selection: $appState.recordingMode) {
                Text("Toggle (press to start/stop)").tag(RecordingMode.toggle)
                Text("Push-to-Talk (hold to record)").tag(RecordingMode.pushToTalk)
            }
            .pickerStyle(.radioGroup)
            .labelsHidden()

            Divider()

            // Quit button
            Button("Quit Option-C") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding()
        .frame(width: 280)
    }
}
