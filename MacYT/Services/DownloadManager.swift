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
    private var detectedOutputURL: URL?
    
    @MainActor
    func startDownload(url: String, formatExpression: String?, options: DownloadOptions) async {
        self.status = .fetching
        self.consoleLogs.removeAll()
        self.detectedOutputURL = nil
        
        var args = options.commandLineFlags()
        if let ffmpegPath = DependencyChecker.shared.installedPath(for: "ffmpeg") {
            let ffmpegDirectory = URL(fileURLWithPath: ffmpegPath).deletingLastPathComponent().path
            args.insert(contentsOf: ["--ffmpeg-location", ffmpegDirectory], at: 0)
        }

        if let fm = formatExpression {
            args.append(contentsOf: ["-f", fm])
        } else if !options.extractAudio {
            args.append(contentsOf: ["-f", "bv*+ba/best"])
        }
        
        args.append(url)
        
        let path = DependencyChecker.shared.getExecutablePath(for: "yt-dlp")
        
        process = Process()
        process?.executableURL = URL(fileURLWithPath: path)
        process?.arguments = args
        var env = ProcessInfo.processInfo.environment
        let existingPathComponents = (env["PATH"] ?? "")
            .split(separator: ":")
            .map(String.init)
        env["PATH"] = Array(NSOrderedSet(array: DependencyChecker.shared.preferredExecutableDirectories() + existingPathComponents))
            .compactMap { $0 as? String }
            .joined(separator: ":")
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
                let resolvedOutputURL = detectedOutputURL ?? options.outputDirectory
                DownloadHistoryStore.shared.recordDownload(at: resolvedOutputURL, sourceURL: url)
                self.status = .completed(filePath: resolvedOutputURL.path)
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
            captureOutputLocation(from: line)
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

    @MainActor
    private func captureOutputLocation(from line: String) {
        if let path = quotedPath(in: line, prefix: "[Merger] Merging formats into ") {
            detectedOutputURL = URL(fileURLWithPath: path)
            return
        }

        if let path = plainPath(in: line, prefix: "[ExtractAudio] Destination: ") {
            detectedOutputURL = URL(fileURLWithPath: path)
            return
        }

        if let path = plainPath(in: line, prefix: "[download] Destination: ") {
            detectedOutputURL = URL(fileURLWithPath: path)
        }
    }

    private func plainPath(in line: String, prefix: String) -> String? {
        guard line.hasPrefix(prefix) else { return nil }
        return String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func quotedPath(in line: String, prefix: String) -> String? {
        guard line.hasPrefix(prefix) else { return nil }

        let remainder = line.dropFirst(prefix.count)

        guard let firstQuoteIndex = remainder.firstIndex(of: "\"") else { return nil }
        let startIndex = remainder.index(after: firstQuoteIndex)
        guard let endIndex = remainder[startIndex...].firstIndex(of: "\"") else { return nil }

        return String(remainder[startIndex..<endIndex])
    }
}

@MainActor
final class DownloadHistoryStore: ObservableObject {
    static let shared = DownloadHistoryStore()

    @Published private(set) var records: [DownloadHistoryRecord] = []
    @Published private(set) var lastError: String?

    private init() {
        refresh()
    }

    func refresh() {
        do {
            let fileURL = try historyFileURL()
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                records = []
                lastError = nil
                return
            }

            let data = try Data(contentsOf: fileURL)
            let decodedRecords = try JSONDecoder().decode([DownloadHistoryRecord].self, from: data)
            records = decodedRecords
                .filter { FileManager.default.fileExists(atPath: $0.filePath) }
                .sorted { $0.downloadedAt > $1.downloadedAt }
            lastError = nil
        } catch {
            records = []
            lastError = "Could not load MacYT download history."
        }
    }

    func recordDownload(at fileURL: URL, sourceURL: String?) {
        let standardizedURL = fileURL.standardizedFileURL

        guard FileManager.default.fileExists(atPath: standardizedURL.path) else {
            return
        }

        let record = DownloadHistoryRecord(
            filePath: standardizedURL.path,
            sourceURL: sourceURL,
            downloadedAt: Date()
        )

        records.removeAll { $0.filePath == record.filePath }
        records.insert(record, at: 0)
        records.sort { $0.downloadedAt > $1.downloadedAt }

        do {
            try persist()
            lastError = nil
        } catch {
            lastError = "Could not save MacYT download history."
        }
    }

    private func persist() throws {
        let fileURL = try historyFileURL()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(records)
        try data.write(to: fileURL, options: .atomic)
    }

    private func historyFileURL() throws -> URL {
        let appSupportDirectory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let appDirectory = appSupportDirectory.appendingPathComponent("MacYT", isDirectory: true)
        try FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true)
        return appDirectory.appendingPathComponent("download-history.json")
    }
}

struct DownloadHistoryRecord: Codable, Identifiable {
    let filePath: String
    let sourceURL: String?
    let downloadedAt: Date

    var id: String { filePath }
}
