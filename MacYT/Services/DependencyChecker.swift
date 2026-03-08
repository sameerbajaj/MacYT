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
        let process = Process()
        let pipe = Pipe()
        
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", "which \(executable)"]
        
        var path = ""
        var defaultPath = "/opt/homebrew/bin/\(executable)" // fallback
        
        process.standardOutput = pipe
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        } catch {
            // Error running shell which
            path = ""
        }
        
        if path.isEmpty {
            if FileManager.default.fileExists(atPath: defaultPath) {
                path = defaultPath
            } else {
                return .missing
            }
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
        let status = executable == "yt-dlp" ? ytdlpStatus : ffmpegStatus
        if case .installed(let path, _) = status {
            return path
        }
        return "/opt/homebrew/bin/\(executable)"
    }
}
