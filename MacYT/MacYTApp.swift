import SwiftUI

@main
struct MacYTApp: App {
    private let updaterController = UpdaterController()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 800, minHeight: 600)
                .background(Color(NSColor.windowBackgroundColor))
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .commands {
            UpdaterCommands(updaterController: updaterController)
        }
    }
}
