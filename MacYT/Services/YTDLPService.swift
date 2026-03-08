import Foundation

class YTDLPService {
    static let shared = YTDLPService()
    
    enum YTDLPError: Error, LocalizedError {
        case fetchFailed(String)
        case decodeFailed
        
        var errorDescription: String? {
            switch self {
            case .fetchFailed(let msg): return "yt-dlp failed: \(msg)"
            case .decodeFailed: return "Failed to parse yt-dlp output"
            }
        }
    }
    
    func fetchVideoInfo(url: String) async throws -> VideoInfo {
        let path = DependencyChecker.shared.getExecutablePath(for: "yt-dlp")
        let process = Process()
        let pipe = Pipe()
        let errPipe = Pipe()
        let sanitizedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["--dump-json", "--no-warnings", sanitizedURL]
        var env = ProcessInfo.processInfo.environment
        let existingPathComponents = (env["PATH"] ?? "")
            .split(separator: ":")
            .map(String.init)
        env["PATH"] = Array(NSOrderedSet(array: DependencyChecker.shared.preferredExecutableDirectories() + existingPathComponents))
            .compactMap { $0 as? String }
            .joined(separator: ":")
        process.environment = env
        
        process.standardOutput = pipe
        process.standardError = errPipe
        
        return try await withCheckedThrowingContinuation { continuation in
            do {
                let stdoutTask = Task.detached(priority: .userInitiated) {
                    pipe.fileHandleForReading.readDataToEndOfFile()
                }
                let stderrTask = Task.detached(priority: .userInitiated) {
                    errPipe.fileHandleForReading.readDataToEndOfFile()
                }

                try process.run()

                Task.detached(priority: .userInitiated) {
                    process.waitUntilExit()
                    let data = await stdoutTask.value
                    let errData = await stderrTask.value
                    let errString = String(data: errData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                    if process.terminationStatus != 0 {
                        continuation.resume(throwing: YTDLPError.fetchFailed(errString.isEmpty ? "No metadata returned by yt-dlp" : errString))
                        return
                    }

                    let decoder = JSONDecoder()
                    decoder.keyDecodingStrategy = .convertFromSnakeCase
                    do {
                        let info = try decoder.decode(VideoInfo.self, from: data)
                        continuation.resume(returning: info)
                    } catch {
                        print("Decode error: \(error)")
                        continuation.resume(throwing: YTDLPError.decodeFailed)
                    }
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
