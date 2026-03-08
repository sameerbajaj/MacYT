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
        
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["--dump-json", "--no-warnings", url]
        
        process.standardOutput = pipe
        process.standardError = errPipe
        
        return try await withCheckedThrowingContinuation { continuation in
            do {
                try process.run()
                
                // Read async to avoid deadlocks
                DispatchQueue.global().async {
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                    let errString = String(data: errData, encoding: .utf8) ?? ""
                    
                    process.waitUntilExit()
                    
                    if process.terminationStatus != 0 {
                        continuation.resume(throwing: YTDLPError.fetchFailed(errString))
                        return
                    }
                    
                    let decoder = JSONDecoder()
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
