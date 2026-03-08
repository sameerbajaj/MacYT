import Foundation
import Combine

enum DownloadStatus: Equatable {
    case idle
    case fetching
    case downloading(percent: Double, speed: String, eta: String)
    case postProcessing
    case completed(filePath: String)
    case failed(error: String)
    case cancelled
}

class DownloadManager: ObservableObject {
    @Published var status: DownloadStatus = .idle
    @Published var currentLine: String = ""
    @Published var consoleLogs: [String] = []
    
    private var process: Process?
    
    @MainActor
    func startDownload(url: String, formatId: String?, options: DownloadOptions) async {
        self.status = .fetching
        self.consoleLogs.removeAll()
        
        var args = options.commandLineFlags()
        if let fm = formatId {
            args.append(contentsOf: ["-f", fm])
        } else if !options.extractAudio {
            args.append(contentsOf: ["-f", "bv*+ba/best"])
        }
        
        args.append(url)
        
        let path = DependencyChecker.shared.getExecutablePath(for: "yt-dlp")
        
        process = Process()
        process?.executableURL = URL(fileURLWithPath: path)
        process?.arguments = args
        // Inject ffmpeg path so yt-dlp uses the correct broken check
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
        process?.environment = env
        
        let pipe = Pipe()
        let errPipe = Pipe()
        process?.standardOutput = pipe
        process?.standardError = errPipe
        
        pipe.fileHandleForReading.readabilityHandler = { fh in
            let data = fh.availableData
            if data.isEmpty { return }
            if let string = String(data: data, encoding: .utf8) {
                Task { @MainActor in
                    self.processOutput(string)
                }
            }
        }
        errPipe.fileHandleForReading.readabilityHandler = { fh in
            let data = fh.availableData
            if data.isEmpty { return }
            if let string = String(data: data, encoding: .utf8) {
                Task { @MainActor in
                    self.processOutput(string)
                }
            }
        }
        
        do {
            try process?.run()
            self.status = .downloading(percent: 0, speed: "0.0B/s", eta: "Unknown")
            
            // Wait for exit
            process?.waitUntilExit()
            
            pipe.fileHandleForReading.readabilityHandler = nil
            errPipe.fileHandleForReading.readabilityHandler = nil
            
            let termStatus = process?.terminationStatus ?? -1
            if termStatus == 0 {
                self.status = .completed(filePath: "Download completed")
            } else if status != .cancelled {
                self.status = .failed(error: "yt-dlp exited with code \(termStatus)")
            }
            
        } catch {
            self.status = .failed(error: error.localizedDescription)
        }
    }
    
    func cancelDownload() {
        process?.terminate()
        status = .cancelled
    }
    
    private let progressRegex = try! NSRegularExpression(pattern: #"\[download\]\s+(\d+(?:\.\d+)?)\%\s+of\s+~?(?:.*?)\s+at\s+([a-zA-Z0-9.\/]+)\s+ETA\s+([0-9:]+)"#)
    
    @MainActor
    private func processOutput(_ text: String) {
        let lines = text.components(separatedBy: .newlines)
        for line in lines where !line.isEmpty {
            self.currentLine = line
            self.consoleLogs.append(line)
            if self.consoleLogs.count > 500 {
                self.consoleLogs.removeFirst(self.consoleLogs.count - 500)
            }
            
            // parsing logic
            if line.contains("[Merger]") || line.contains("[ExtractAudio]") {
                self.status = .postProcessing
            } else if let match = progressRegex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {
                if let pctRange = Range(match.range(at: 1), in: line),
                   let spdRange = Range(match.range(at: 2), in: line),
                   let etaRange = Range(match.range(at: 3), in: line),
                   let pct = Double(line[pctRange]) {
                    let spd = String(line[spdRange])
                    let eta = String(line[etaRange])
                    self.status = .downloading(percent: pct / 100.0, speed: spd, eta: eta)
                }
            }
        }
    }
}
