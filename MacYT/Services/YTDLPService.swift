import Foundation
import OSLog

class YTDLPService {
    static let shared = YTDLPService()
    private let logger = Logger(subsystem: "luminoslabs.MacYT", category: "YTDLPService")
    
    enum YTDLPError: Error, LocalizedError {
        case fetchFailed(String)
        case decodeFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .fetchFailed(let msg): return "yt-dlp failed: \(msg)"
            case .decodeFailed(let msg): return msg
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

        logger.info("Inspect started for URL: \(sanitizedURL, privacy: .public)")
        
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

                    self.logger.info("Inspect finished with exit code: \(process.terminationStatus), stdout bytes: \(data.count), stderr bytes: \(errData.count)")

                    if process.terminationStatus != 0 {
                        self.logger.error("yt-dlp inspect failed: \(errString, privacy: .public)")
                        continuation.resume(throwing: YTDLPError.fetchFailed(errString.isEmpty ? "No metadata returned by yt-dlp" : errString))
                        return
                    }

                    let decoder = JSONDecoder()
                    do {
                        let info = try decoder.decode(VideoInfo.self, from: data)
                        self.logger.info("Decoded yt-dlp payload for video: \(info.id, privacy: .public) title: \(info.title, privacy: .public)")
                        continuation.resume(returning: info)
                    } catch {
                        let details = Self.describeDecodingError(error)
                        let dumpURL = Self.persistDebugArtifacts(stdout: data, stderr: errData)
                        let message = "Failed to parse yt-dlp output. \(details)\(dumpURL.map { " Raw response saved to \($0.path)." } ?? "")"
                        self.logger.error("Decode failure: \(details, privacy: .public)")
                        continuation.resume(throwing: YTDLPError.decodeFailed(message))
                    }
                }
            } catch {
                logger.error("Failed to launch yt-dlp: \(error.localizedDescription, privacy: .public)")
                continuation.resume(throwing: error)
            }
        }
    }

    nonisolated private static func describeDecodingError(_ error: Error) -> String {
        switch error {
        case let DecodingError.typeMismatch(type, context):
            return "Type mismatch for \(type) at \(codingPath(context.codingPath)): \(context.debugDescription)"
        case let DecodingError.valueNotFound(type, context):
            return "Missing value for \(type) at \(codingPath(context.codingPath)): \(context.debugDescription)"
        case let DecodingError.keyNotFound(key, context):
            return "Missing key '\(key.stringValue)' at \(codingPath(context.codingPath)): \(context.debugDescription)"
        case let DecodingError.dataCorrupted(context):
            return "Corrupted data at \(codingPath(context.codingPath)): \(context.debugDescription)"
        default:
            return error.localizedDescription
        }
    }

    nonisolated private static func codingPath(_ codingPath: [CodingKey]) -> String {
        let joined = codingPath.map(\.stringValue).joined(separator: ".")
        return joined.isEmpty ? "<root>" : joined
    }

    nonisolated private static func persistDebugArtifacts(stdout: Data, stderr: Data) -> URL? {
        let fileManager = FileManager.default
        let logsDirectory = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/MacYT", isDirectory: true)

        do {
            try fileManager.createDirectory(at: logsDirectory, withIntermediateDirectories: true)
            let stdoutURL = logsDirectory.appendingPathComponent("last-ytdlp-output.json")
            let stderrURL = logsDirectory.appendingPathComponent("last-ytdlp-error.log")
            try stdout.write(to: stdoutURL, options: .atomic)
            try stderr.write(to: stderrURL, options: .atomic)
            return stdoutURL
        } catch {
            return nil
        }
    }
}
