import SwiftUI

struct MenuBarView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var replacements = TextReplacementManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Status
            statusSection

            Divider()

            // Recording Mode
            recordingModeSection

            Divider()

            // Whisper Model
            whisperModelSection

            Divider()

            // Text Replacements
            replacementsSection

            Divider()

            // Options
            optionsSection

            Divider()

            // Quit
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding()
        .frame(width: 260)
    }

    // MARK: - Status Section

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)

                Text(statusText)
                    .font(.system(.body, design: .rounded, weight: .medium))

                Spacer()

                if appState.whisperModelLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }

            HStack(spacing: 4) {
                Text("Shortcut:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("⌃⇧Space")
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.15))
                    .cornerRadius(4)
            }
        }
    }

    private var statusColor: Color {
        if appState.whisperModelLoading {
            return .orange
        } else if !appState.whisperModelLoaded {
            return .red
        } else {
            switch appState.currentState {
            case .idle: return .green
            case .recording: return .red
            case .processing: return .orange
            case .success: return .green
            case .error: return .red
            }
        }
    }

    private var statusText: String {
        if appState.whisperModelLoading {
            return "Downloading model..."
        } else if !appState.whisperModelLoaded {
            return "Model not loaded"
        } else {
            return appState.currentState.displayName
        }
    }

    // MARK: - Recording Mode Section

    private var recordingModeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MODE")
                .font(.caption)
                .foregroundColor(.secondary)
                .fontWeight(.semibold)

            modeButton(
                title: "Toggle",
                subtitle: "Press to start/stop",
                isSelected: appState.recordingMode == .toggle,
                action: { appState.recordingMode = .toggle }
            )

            modeButton(
                title: "Push-to-Talk",
                subtitle: "Hold to record",
                isSelected: appState.recordingMode == .pushToTalk,
                action: { appState.recordingMode = .pushToTalk }
            )
        }
    }

    private func modeButton(title: String, subtitle: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .fontWeight(isSelected ? .semibold : .regular)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.accentColor)
                        .fontWeight(.semibold)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Whisper Model Section

    private var whisperModelSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TRANSCRIPTION MODEL")
                .font(.caption)
                .foregroundColor(.secondary)
                .fontWeight(.semibold)

            ForEach(WhisperModels.all, id: \.id) { model in
                modelButton(model: model)
            }
        }
    }

    private func modelButton(model: WhisperModels.Model) -> some View {
        let isSelected = appState.selectedWhisperModel == model.id

        return Button(action: {
            if !isSelected {
                appState.changeWhisperModel(to: model.id)
            }
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.name)
                        .fontWeight(isSelected ? .semibold : .regular)
                    Text(model.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if isSelected && appState.whisperModelLoading {
                    ProgressView()
                        .scaleEffect(0.6)
                } else if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.accentColor)
                        .fontWeight(.semibold)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Text Replacements Section

    private var replacementsSection: some View {
        Button(action: { ReplacementsWindowController.shared.show() }) {
            Text("Edit Replacements...")
        }
        .buttonStyle(.plain)
    }

    // MARK: - Options Section

    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("OPTIONS")
                .font(.caption)
                .foregroundColor(.secondary)
                .fontWeight(.semibold)

            Toggle("Auto-paste after transcription", isOn: $appState.autoPasteEnabled)
                .toggleStyle(.checkbox)
                .onChange(of: appState.autoPasteEnabled) { _, enabled in
                    if enabled {
                        appState.requestAccessibilityIfNeeded()
                    }
                }

            if appState.autoPasteEnabled && !appState.isAccessibilityGranted {
                Button(action: { appState.requestAccessibilityIfNeeded() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                        Text("Grant Accessibility")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Whisper Models Data

enum WhisperModels {
    struct Model {
        let id: String
        let name: String
        let description: String
    }

    static let all: [Model] = [
        Model(id: "openai_whisper-tiny", name: "Whisper Tiny", description: "Fastest, ~40MB"),
        Model(id: "openai_whisper-base", name: "Whisper Base", description: "Balanced, ~150MB"),
        Model(id: "openai_whisper-small", name: "Whisper Small", description: "Better, ~500MB"),
        Model(id: "openai_whisper-large-v3", name: "Whisper Large", description: "Best, ~3GB")
    ]
}
