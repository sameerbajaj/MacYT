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
}

class DependencyChecker: ObservableObject {
    static let shared = DependencyChecker()
    
    @Published var ytdlpStatus: DependencyStatus = .checking
    @Published var ffmpegStatus: DependencyStatus = .checking
    
    private init() {}

    var allRequiredInstalled: Bool {
        ytdlpStatus.isInstalled && ffmpegStatus.isInstalled
    }

    var unresolvedDependenciesDescription: String {
        var missing: [String] = []

        if !ytdlpStatus.isInstalled {
            missing.append("yt-dlp")
        }

        if !ffmpegStatus.isInstalled {
            missing.append("FFmpeg")
        }

        if missing.isEmpty {
            return "All dependencies are installed."
        }

        return "Missing or broken: \(missing.joined(separator: ", "))"
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
        
        // Check version to see if it's broken
        let versionProcess = Process()
        let vPipe = Pipe()
        let vErrPipe = Pipe()
        
        versionProcess.executableURL = URL(fileURLWithPath: path)
        if executable == "yt-dlp" {
            versionProcess.arguments = ["--version"]
        } else {
            versionProcess.arguments = ["-version"]
        }
        
        versionProcess.standardOutput = vPipe
        versionProcess.standardError = vErrPipe
        
        do {
            try versionProcess.run()
            versionProcess.waitUntilExit()
            
            let vData = vPipe.fileHandleForReading.readDataToEndOfFile()
            let vErrData = vErrPipe.fileHandleForReading.readDataToEndOfFile()
            
            var output = String(data: vData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let errorOut = String(data: vErrData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            
            if versionProcess.terminationStatus != 0 {
                return .broken(path: path, error: errorOut.isEmpty ? output : errorOut)
            }
            
            if executable == "ffmpeg" {
                output = output.components(separatedBy: "\n").first ?? output
            }
            
            return .installed(path: path, version: output)
            
        } catch {
            return .broken(path: path, error: error.localizedDescription)
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
        for candidate in candidatePaths(for: executable) where FileManager.default.isExecutableFile(atPath: candidate) {
            return candidate
        }

        return nil
    }

    private func candidatePaths(for executable: String) -> [String] {
        let fileManager = FileManager.default
        let homeDirectory = fileManager.homeDirectoryForCurrentUser
        let environmentPaths = (ProcessInfo.processInfo.environment["PATH"] ?? "")
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

        return uniquePaths(candidates)
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
