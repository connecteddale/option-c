import SwiftUI

@main
struct OptionCApp: App {
    @StateObject private var appState = AppState()

    init() {
        // Request notification permission on launch (async, non-blocking)
        Task {
            await NotificationManager.shared.requestPermission()
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(appState: appState)
        } label: {
            Image(systemName: appState.menuBarIcon)
                .symbolRenderingMode(.multicolor)
        }
    }
}
