import AppKit
import Foundation

enum SelfUpdateState: Equatable {
    case idle
    case downloading(progress: Double)
    case installing
    case failed(String)
}

enum SelfUpdater {
    static func update(
        dmgURL: URL,
        onStateChange: @escaping @MainActor (SelfUpdateState) -> Void
    ) async {
        do {
            await MainActor.run { onStateChange(.downloading(progress: 0)) }
            let localDMG = try await downloadDMG(from: dmgURL) { fraction in
                Task { @MainActor in
                    onStateChange(.downloading(progress: fraction))
                }
            }

            await MainActor.run { onStateChange(.installing) }
            let mountPoint = try await mountDMG(at: localDMG)
            defer {
                unmountDMG(mountPoint: mountPoint)
                try? FileManager.default.removeItem(at: localDMG)
            }

            let runningAppURL = Bundle.main.bundleURL
            let expectedAppName = runningAppURL.lastPathComponent
            let newAppURL = try locateApp(in: mountPoint, preferredAppName: expectedAppName)

            try replaceApp(old: runningAppURL, with: newAppURL)
            relaunchApp(at: runningAppURL)
        } catch {
            await MainActor.run { onStateChange(.failed(error.localizedDescription)) }
        }
    }

    private static func downloadDMG(
        from url: URL,
        progress: @escaping (Double) -> Void
    ) async throws -> URL {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MacYT-Update", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        let destinationURL = tempDirectory.appendingPathComponent("update.dmg")
        try? FileManager.default.removeItem(at: destinationURL)

        let delegate = DownloadDelegate(progress: progress)
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)

        return try await withCheckedThrowingContinuation { continuation in
            let task = session.downloadTask(with: url) { temporaryURL, _, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let temporaryURL else {
                    continuation.resume(throwing: UpdateError.downloadFailed)
                    return
                }

                do {
                    try FileManager.default.moveItem(at: temporaryURL, to: destinationURL)
                    continuation.resume(returning: destinationURL)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            task.resume()
        }
    }

    private static func mountDMG(at dmgURL: URL) async throws -> URL {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        process.arguments = [
            "attach", dmgURL.path,
            "-nobrowse",
            "-readonly",
            "-mountrandom", "/tmp",
            "-plist"
        ]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw UpdateError.mountFailed
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let entities = plist["system-entities"] as? [[String: Any]] else {
            throw UpdateError.mountFailed
        }

        for entity in entities {
            if let mountPoint = entity["mount-point"] as? String {
                return URL(fileURLWithPath: mountPoint)
            }
        }

        throw UpdateError.mountFailed
    }

    private static func unmountDMG(mountPoint: URL) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        process.arguments = ["detach", mountPoint.path, "-quiet"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
    }

    private static func locateApp(in volume: URL, preferredAppName: String) throws -> URL {
        let contents = try FileManager.default.contentsOfDirectory(
            at: volume,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey]
        )
        let candidates = contents.filter { $0.pathExtension.lowercased() == "app" }

        if let preferred = candidates.first(where: { $0.lastPathComponent == preferredAppName }) {
            return preferred
        }

        if candidates.count == 1, let only = candidates.first {
            return only
        }

        if let fallback = candidates.first(where: { $0.lastPathComponent.lowercased().contains("macyt") }) {
            return fallback
        }

        guard let app = candidates.first else {
            throw UpdateError.appNotFoundInDMG
        }
        return app
    }

    private static func replaceApp(old: URL, with new: URL) throws {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: old.path) else {
            throw UpdateError.currentAppNotFound
        }

        let parent = old.deletingLastPathComponent()
        let staged = parent.appendingPathComponent(".MacYT-update-staging.app")
        let backup = parent.appendingPathComponent(".MacYT-update-backup.app")

        try? fileManager.removeItem(at: staged)
        try? fileManager.removeItem(at: backup)
        try fileManager.copyItem(at: new, to: staged)
        clearQuarantine(at: staged)

        do {
            try fileManager.moveItem(at: old, to: backup)
            try fileManager.moveItem(at: staged, to: old)
            try verifyCodeSignature(at: old)
            try? fileManager.removeItem(at: backup)
        } catch {
            try? fileManager.removeItem(at: old)
            if fileManager.fileExists(atPath: backup.path) {
                try? fileManager.moveItem(at: backup, to: old)
            }
            throw UpdateError.installFailed(error.localizedDescription)
        }
    }

    private static func clearQuarantine(at appURL: URL) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
        process.arguments = ["-dr", "com.apple.quarantine", appURL.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
    }

    private static func verifyCodeSignature(at appURL: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        process.arguments = ["--verify", "--deep", "--strict", appURL.path]
        process.standardOutput = FileHandle.nullDevice

        let stderrPipe = Pipe()
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let data = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            throw UpdateError.invalidUpdatedApp(message ?? "Code signature verification failed.")
        }
    }

    private static func relaunchApp(at appURL: URL) {
        let pid = ProcessInfo.processInfo.processIdentifier
        let appPath = appURL.path
        let script = """
        #!/bin/bash
        for i in $(seq 1 20); do
            kill -0 \(pid) 2>/dev/null || break
            sleep 0.5
        done
        open "\(appPath)"
        """

        let scriptURL = FileManager.default.temporaryDirectory.appendingPathComponent("macyt-relaunch.sh")
        try? script.write(to: scriptURL, atomically: true, encoding: .utf8)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [scriptURL.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        process.qualityOfService = .utility
        try? process.run()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NSApplication.shared.terminate(nil)
        }
    }

    enum UpdateError: LocalizedError {
        case downloadFailed
        case mountFailed
        case appNotFoundInDMG
        case currentAppNotFound
        case invalidUpdatedApp(String)
        case installFailed(String)

        var errorDescription: String? {
            switch self {
            case .downloadFailed:
                return "Failed to download the update."
            case .mountFailed:
                return "Failed to open the downloaded image."
            case .appNotFoundInDMG:
                return "No app found in the update image."
            case .currentAppNotFound:
                return "Cannot locate the running app to replace."
            case .invalidUpdatedApp(let details):
                return "The downloaded app failed verification. \(details)"
            case .installFailed(let details):
                return "Failed to install the update. \(details)"
            }
        }
    }
}

private final class DownloadDelegate: NSObject, URLSessionDownloadDelegate {
    let onProgress: (Double) -> Void

    init(progress: @escaping (Double) -> Void) {
        self.onProgress = progress
        super.init()
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let fraction = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        onProgress(fraction)
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        // handled in the completion handler above
    }
}
