import AppKit
import Foundation
import Sparkle

@MainActor
final class UpdaterController {
    let isConfigured: Bool

    private let updaterController: SPUStandardUpdaterController?

    init() {
        let feedURL = (Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let publicKey = (Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        self.isConfigured = !feedURL.isEmpty && !publicKey.isEmpty && !publicKey.contains("TODO_")
        self.updaterController = isConfigured
            ? SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
            : nil
    }

    func checkForUpdates() {
        guard let updaterController else {
            let alert = NSAlert()
            alert.messageText = "Updater Setup Incomplete"
            alert.informativeText = "Set `SUPublicEDKey` and publish `appcast.xml` before using in-app updates."
            alert.alertStyle = .informational
            alert.runModal()
            return
        }

        updaterController.checkForUpdates(nil)
    }
}
