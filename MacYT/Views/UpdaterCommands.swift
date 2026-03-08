import SwiftUI

struct UpdaterCommands: Commands {
    let updaterController: UpdaterController

    var body: some Commands {
        CommandGroup(after: .appInfo) {
            Divider()
            Button("Check for Updates…") {
                updaterController.checkForUpdates()
            }
            .disabled(!updaterController.isConfigured)
        }
    }
}
