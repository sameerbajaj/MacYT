import Foundation
import Combine

enum DependencyStatus: Equatable {
    case installed(path: String, version: String)
    case broken(path: String, error: String)
    case missing
    case checking
    
    var isInstalled: Bool {
        if case .installed = self { return true }
        return false
    }

    var isBroken: Bool {
        if case .broken = self { return true }
        return false
    }

    var title: String {
        switch self {
        case .installed:
            return "Ready"
        case .broken:
            return "Broken"
        case .missing:
            return "Missing"
        case .checking:
            return "Scanning"
        }
    }

    var detail: String? {
        switch self {
        case .installed(let path, let version):
            return [version, path]
                .filter { !$0.isEmpty }
                .joined(separator: " • ")
        case .broken(let path, let error):
            return [path, error]
                .filter { !$0.isEmpty }
                .joined(separator: " • ")
        case .missing:
            return nil
        case .checking:
            return "Looking across Homebrew, system paths, and your login shell."
        }
    }
}

class DependencyChecker: ObservableObject {
    static let shared = DependencyChecker()
    
    @Published var ytdlpStatus: DependencyStatus = .checking
    @Published var ffmpegStatus: DependencyStatus = .checking
    
    private init() {}

    var coreDependencyInstalled: Bool {
        ytdlpStatus.isInstalled
    }

    var allRequiredInstalled: Bool {
        ytdlpStatus.isInstalled && ffmpegStatus.isInstalled
    }

    var unresolvedDependenciesDescription: String {
        let issues = [dependencySummary(name: "yt-dlp", status: ytdlpStatus), dependencySummary(name: "FFmpeg", status: ffmpegStatus)]
            .compactMap { $0 }

        if issues.isEmpty {
            return "All dependencies are installed."
        }

        return issues.joined(separator: " • ")
    }

    var ffmpegWarningText: String? {
        switch ffmpegStatus {
        case .installed:
            return nil
        case .checking:
            return "Checking FFmpeg support…"
        case .missing:
            return "FFmpeg is optional for browsing formats, but downloads that need merging or audio extraction will stay unavailable until it is installed."
        case .broken(_, let error):
            return "FFmpeg was found, but macOS could not launch it. \(concise(error))"
        }
    }
    
    @MainActor
    func checkAll() async {
        ytdlpStatus = .checking
        ffmpegStatus = .checking
        
        async let yt = check(executable: "yt-dlp")
        async let ff = check(executable: "ffmpeg")
        
        let (ytResult, ffResult) = await (yt, ff)
        
        ytdlpStatus = ytResult
        ffmpegStatus = ffResult
    }
    
    func check(executable: String) async -> DependencyStatus {
        guard let path = resolveExecutablePath(for: executable) else {
            return .missing
        }

        let versionProcess = Process()
        let vPipe = Pipe()
        let vErrPipe = Pipe()

        versionProcess.executableURL = URL(fileURLWithPath: path)
        versionProcess.arguments = versionArguments(for: executable)
        versionProcess.standardOutput = vPipe
        versionProcess.standardError = vErrPipe
        versionProcess.environment = launchEnvironment()

        do {
            let stdoutTask = Task.detached(priority: .userInitiated) {
                vPipe.fileHandleForReading.readDataToEndOfFile()
            }
            let stderrTask = Task.detached(priority: .userInitiated) {
                vErrPipe.fileHandleForReading.readDataToEndOfFile()
            }

            try versionProcess.run()
            versionProcess.waitUntilExit()

            let vData = await stdoutTask.value
            let vErrData = await stderrTask.value

            let stdout = String(data: vData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let stderr = String(data: vErrData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            var output = stdout.isEmpty ? stderr : stdout

            if versionProcess.terminationStatus != 0 {
                return .broken(path: path, error: diagnoseFailure(stdout: stdout, stderr: stderr))
            }

            if executable == "ffmpeg" {
                output = output.components(separatedBy: "\n").first ?? output
            }

            return .installed(path: path, version: output)

        } catch {
            return .broken(path: path, error: concise(error.localizedDescription))
        }
    }
    
    func getExecutablePath(for executable: String) -> String {
        installedPath(for: executable)
            ?? resolveExecutablePath(for: executable)
            ?? "/opt/homebrew/bin/\(executable)"
    }

    func installedPath(for executable: String) -> String? {
        let status = executable == "yt-dlp" ? ytdlpStatus : ffmpegStatus
        if case .installed(let path, _) = status {
            return path
        }
        return nil
    }

    func preferredExecutableDirectories() -> [String] {
        let installedDirectories = [installedPath(for: "yt-dlp"), installedPath(for: "ffmpeg")]
            .compactMap { $0 }
            .map { URL(fileURLWithPath: $0).deletingLastPathComponent().path }

        let fallbackDirectories = [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".local/bin").path,
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/MacYT/bin").path
        ]

        return uniquePaths(installedDirectories + fallbackDirectories)
    }

    private func resolveExecutablePath(for executable: String) -> String? {
        if let shellResolved = shellResolvedPath(for: executable),
           FileManager.default.isExecutableFile(atPath: shellResolved) {
            return URL(fileURLWithPath: shellResolved).resolvingSymlinksInPath().path
        }

        for candidate in candidatePaths(for: executable) where FileManager.default.isExecutableFile(atPath: candidate) {
            return URL(fileURLWithPath: candidate).resolvingSymlinksInPath().path
        }

        return nil
    }

    private func candidatePaths(for executable: String) -> [String] {
        let fileManager = FileManager.default
        let homeDirectory = fileManager.homeDirectoryForCurrentUser
        let environmentPaths = launchEnvironment()["PATH", default: ""]
            .split(separator: ":")
            .map(String.init)
            .map { URL(fileURLWithPath: $0).appendingPathComponent(executable).path }

        var candidates = environmentPaths
        candidates.append(contentsOf: [
            "/opt/homebrew/bin/\(executable)",
            "/usr/local/bin/\(executable)",
            "/usr/bin/\(executable)",
            homeDirectory.appendingPathComponent(".local/bin/\(executable)").path,
            homeDirectory.appendingPathComponent("Library/Application Support/MacYT/bin/\(executable)").path
        ])

        if let resourceURL = Bundle.main.resourceURL {
            candidates.append(resourceURL.appendingPathComponent("bin/\(executable)").path)
        }

        candidates.append(contentsOf: pythonUserBinCandidates(for: executable))
        candidates.append(contentsOf: homebrewOptCandidates(for: executable))

        return uniquePaths(candidates)
    }

    private func dependencySummary(name: String, status: DependencyStatus) -> String? {
        switch status {
        case .installed:
            return nil
        case .checking:
            return "\(name) is still being checked."
        case .missing:
            return "\(name) is missing."
        case .broken(_, let error):
            return "\(name) is broken: \(concise(error))"
        }
    }

    private func versionArguments(for executable: String) -> [String] {
        executable == "yt-dlp" ? ["--version"] : ["-version"]
    }

    private func launchEnvironment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        let existingPathComponents = (environment["PATH"] ?? "")
            .split(separator: ":")
            .map(String.init)
        environment["PATH"] = uniquePaths(preferredExecutableDirectories() + existingPathComponents)
            .joined(separator: ":")
        return environment
    }

    private func shellResolvedPath(for executable: String) -> String? {
        let shellProcess = Process()
        let pipe = Pipe()

        shellProcess.executableURL = URL(fileURLWithPath: "/bin/zsh")
        shellProcess.arguments = ["-lc", "command -v \(shellEscaped(executable)) 2>/dev/null | head -n 1"]
        shellProcess.standardOutput = pipe
        shellProcess.standardError = Pipe()
        shellProcess.environment = launchEnvironment()

        do {
            try shellProcess.run()
            shellProcess.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard shellProcess.terminationStatus == 0, let output, !output.isEmpty else {
                return nil
            }

            return output
        } catch {
            return nil
        }
    }

    private func homebrewOptCandidates(for executable: String) -> [String] {
        let formula = executable == "yt-dlp" ? "yt-dlp" : "ffmpeg"
        return [
            "/opt/homebrew/opt/\(formula)/bin/\(executable)",
            "/usr/local/opt/\(formula)/bin/\(executable)"
        ]
    }

    private func diagnoseFailure(stdout: String, stderr: String) -> String {
        let combined = [stderr, stdout]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")

        if let missingLibrary = missingLibraryName(in: combined) {
            return "Missing shared library: \(missingLibrary). Try repairing the related Homebrew package, then re-check."
        }

        return concise(combined)
    }

    private func missingLibraryName(in text: String) -> String? {
        guard let libraryRange = text.range(of: "Library not loaded: ") else {
            return nil
        }

        let suffix = text[libraryRange.upperBound...]
        let line = suffix.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? ""
        return line.split(separator: "/").last.map(String.init)
    }

    private func concise(_ text: String) -> String {
        let normalized = text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "  +", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard normalized.count > 220 else {
            return normalized
        }

        let index = normalized.index(normalized.startIndex, offsetBy: 217)
        return String(normalized[..<index]) + "..."
    }

    private func shellEscaped(_ string: String) -> String {
        "'" + string.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private func pythonUserBinCandidates(for executable: String) -> [String] {
        let root = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Python")

        guard let versionDirectories = try? FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return versionDirectories.map {
            $0.appendingPathComponent("bin/\(executable)").path
        }
    }

    private func uniquePaths(_ paths: [String]) -> [String] {
        Array(NSOrderedSet(array: paths.filter { !$0.isEmpty }))
            .compactMap { $0 as? String }
    }
}
