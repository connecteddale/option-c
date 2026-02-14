# Option-C

A macOS menu bar app for voice-to-text transcription. Press a keyboard shortcut, speak, and your words are transcribed and placed on the clipboard (or auto-pasted into the active app).

Runs entirely on-device using [WhisperKit](https://github.com/argmaxinc/WhisperKit) — no cloud services, no API keys, no data leaves your Mac.

## Requirements

- macOS 14 (Sonoma) or later
- Apple Silicon or Intel Mac

## Build & Install

```bash
bash bundle-app.sh
cp -r .build/Option-C.app /Applications/
open /Applications/Option-C.app
```

The build script compiles a release binary and creates a signed `.app` bundle.

## Usage

**Keyboard shortcut:** `Control + Shift + Space`

Two recording modes (configurable in the menu):

- **Push-to-Talk** — Hold the shortcut to record, release to stop and transcribe
- **Toggle** — Press once to start recording, press again to stop

After transcription, the text is copied to the clipboard. With **auto-paste** enabled, it also simulates `Cmd+V` to paste into the active app.

## Features

- **Multiple Whisper models** — Choose between Tiny (~40MB), Base (~150MB), Small (~500MB), and Large (~3GB) depending on your speed/accuracy preference. Models are downloaded once and cached.
- **Auto-paste** — Automatically paste transcription into the active app after recording. Requires Accessibility permission.
- **Text replacements** — Define find/replace rules to fix recurring transcription quirks (e.g. "dot dot dot" → "..."). Smart matching handles punctuation variations Whisper may add between words. Supports `\n` and `\t` escape sequences.
- **Menu bar feedback** — The menu bar icon changes to reflect the current state: mic (ready), filled mic (recording), ellipsis (processing), checkmark (done), or X (error).

## Permissions

On first launch, the app will request:

- **Microphone** — Required for recording audio
- **Accessibility** — Required for auto-paste (simulates keyboard input). Grant via System Settings > Privacy & Security > Accessibility.

## Code Signing

The build script signs the app with an "OptionC Dev" self-signed certificate. This keeps Accessibility permissions stable across rebuilds. To create the certificate (one-time setup):

```bash
openssl req -x509 -newkey rsa:2048 \
    -keyout /tmp/optionc-key.pem \
    -out /tmp/optionc-cert.pem \
    -days 3650 -nodes \
    -subj "/CN=OptionC Dev" \
    -addext "keyUsage=digitalSignature" \
    -addext "extendedKeyUsage=codeSigning" 2>/dev/null

openssl pkcs12 -export -out /tmp/optionc.p12 \
    -inkey /tmp/optionc-key.pem \
    -in /tmp/optionc-cert.pem \
    -passout pass:temp123 -legacy 2>/dev/null

security import /tmp/optionc.p12 \
    -k ~/Library/Keychains/login.keychain-db \
    -T /usr/bin/codesign -P "temp123"

security add-trusted-cert -r trustRoot \
    -k ~/Library/Keychains/login.keychain-db \
    -p codeSign /tmp/optionc-cert.pem

rm -f /tmp/optionc-key.pem /tmp/optionc-cert.pem /tmp/optionc.p12
```

If you don't have the certificate, the build script will fall back to ad-hoc signing (but you'll need to re-grant Accessibility after each rebuild).

## Project Structure

```
Sources/OptionC/
  OptionCApp.swift              # App entry point (MenuBarExtra)
  State/AppState.swift          # Central state coordinator
  Audio/AudioCaptureManager.swift   # Microphone capture
  Recording/RecordingController.swift # Recording + transcription pipeline
  Transcription/WhisperTranscriptionEngine.swift # WhisperKit integration
  Clipboard/ClipboardManager.swift  # Clipboard operations
  Models/
    RecordingState.swift        # State enum (idle/recording/processing/success/error)
    RecordingMode.swift         # Toggle vs push-to-talk
    TextReplacement.swift       # Find/replace rules + manager
    AppError.swift              # Error types
  Views/
    MenuBarView.swift           # Menu bar dropdown UI
    ReplacementsWindow.swift    # Text replacements editor (NSPanel)
  Services/
    PermissionManager.swift     # Microphone permission handling
  KeyboardShortcuts+Names.swift # Global shortcut definition
  Resources/Info.plist          # App bundle configuration
```
