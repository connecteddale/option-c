import SwiftUI

@main
struct OptionCApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            Text("Menu Content")
        } label: {
            Image(systemName: appState.menuBarIcon)
                .symbolRenderingMode(.multicolor)
        }
    }
}
