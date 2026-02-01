import SwiftUI

@main
struct OptionCApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(appState: appState)
        } label: {
            Image(systemName: appState.menuBarIcon)
                .symbolRenderingMode(.multicolor)
        }
    }
}
