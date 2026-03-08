import AppKit
import Foundation

@MainActor
final class UpdaterController {
    private var isChecking = false

    init() {
        Task {
            await checkForUpdates(userInitiated: false)
        }
    }

    func checkForUpdatesFromMenu() {
        Task {
            await checkForUpdates(userInitiated: true)
        }
    }

    private func checkForUpdates(userInitiated: Bool) async {
        guard !isChecking else { return }
        isChecking = true
        defer { isChecking = false }

        let update = await UpdateChecker.check()

        guard let update else {
            if userInitiated {
                showAlert(
                    title: "MacYT is Up to Date",
                    message: "No newer GitHub release was found."
                )
            }
            return
        }

        presentUpdateAlert(for: update)
    }

    private func presentUpdateAlert(for update: UpdateInfo) {
        let alert = NSAlert()
        alert.messageText = update.isRolling ? "New Build Available" : "Update Available"
        alert.informativeText = update.isRolling
            ? "A newer GitHub Actions build is available. MacYT can install it now and relaunch automatically."
            : "MacYT \(update.version) is available on GitHub. MacYT can install it now and relaunch automatically."
        alert.alertStyle = .informational

        if update.downloadURL != nil {
            alert.addButton(withTitle: "Install Now")
            alert.addButton(withTitle: "Open Release")
            alert.addButton(withTitle: "Later")
        } else {
            alert.addButton(withTitle: "Open Release")
            alert.addButton(withTitle: "Later")
        }

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            if let downloadURL = update.downloadURL {
                installUpdate(from: downloadURL, metadata: update)
            } else {
                NSWorkspace.shared.open(update.releaseURL)
            }
        case .alertSecondButtonReturn:
            if update.downloadURL != nil {
                NSWorkspace.shared.open(update.releaseURL)
            }
        default:
            break
        }
    }

    private func installUpdate(from dmgURL: URL, metadata: UpdateInfo) {
        if metadata.isRolling, let publishedAt = metadata.publishedAt {
            UpdateChecker.recordInstalledRollingTimestamp(publishedAt)
        }

        Task {
            await SelfUpdater.update(dmgURL: dmgURL) { [weak self] state in
                guard let self else { return }
                self.handleUpdateState(state)
            }
        }
    }

    private func handleUpdateState(_ state: SelfUpdateState) {
        if case .failed(let message) = state {
            showAlert(title: "Update Failed", message: message)
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.runModal()
    }
}
