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
    private var downloadStartedAt: Date?
    private var lastKnownSpeed: String = "0.0B/s"
    private var lastKnownETA: String = "Unknown"
    
    @MainActor
    func startDownload(url: String, formatExpression: String?, options: DownloadOptions) async {
        self.status = .fetching
        self.consoleLogs.removeAll()
        self.detectedOutputURL = nil
        self.downloadStartedAt = Date()
        self.lastKnownSpeed = "0.0B/s"
        self.lastKnownETA = "Unknown"
        
        var args = options.commandLineFlags()
        args.append(contentsOf: ["--print", "after_move:filepath"])
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
            
            let termStatus = await waitForProcessExit()
            
            pipe.fileHandleForReading.readabilityHandler = nil
            errPipe.fileHandleForReading.readabilityHandler = nil
            process = nil
            
            if termStatus == 0 {
                if let resolvedOutputURL = resolveCompletedOutputURL(fallbackDirectory: options.outputDirectory) {
                    DownloadHistoryStore.shared.recordDownload(at: resolvedOutputURL, sourceURL: url)
                    DownloadHistoryStore.shared.refresh()
                    self.status = .completed(filePath: resolvedOutputURL.path)
                } else {
                    self.status = .failed(error: "Download finished, but MacYT could not locate the exported file.")
                }
            } else if status != .cancelled {
                self.status = .failed(error: "yt-dlp exited with code \(termStatus)")
            }
            
        } catch {
            self.status = .failed(error: error.localizedDescription)
        }
    }
    
    func cancelDownload() {
        process?.terminate()
        process = nil
        status = .cancelled
    }
    
    private let progressRegex = try! NSRegularExpression(pattern: #"\[download\]\s+(\d+(?:\.\d+)?)\%"#)
    private let speedRegex = try! NSRegularExpression(pattern: #"\sat\s+([a-zA-Z0-9.\/]+)"#)
    private let etaRegex = try! NSRegularExpression(pattern: #"\sETA\s+([0-9:]+)"#)
    
    @MainActor
    private func processOutput(_ text: String) {
        let normalized = text.replacingOccurrences(of: "\r", with: "\n")
        let lines = normalized.components(separatedBy: .newlines)
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
                   let pct = Double(line[pctRange]) {
                    if let speed = captureFirstGroup(from: speedRegex, in: line) {
                        lastKnownSpeed = speed
                    }
                    if let eta = captureFirstGroup(from: etaRegex, in: line) {
                        lastKnownETA = eta
                    }

                    let progress = max(0, min(1, pct / 100.0))
                    if progress >= 1 && !line.contains("ETA") {
                        self.status = .postProcessing
                    } else {
                        self.status = .downloading(percent: progress, speed: lastKnownSpeed, eta: lastKnownETA)
                    }
                }
            }
        }
    }

    @MainActor
    private func captureOutputLocation(from line: String) {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)

        if let path = existingFilePathIfAny(in: trimmedLine) {
            detectedOutputURL = URL(fileURLWithPath: path)
            return
        }

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

    private func waitForProcessExit() async -> Int32 {
        guard let process else { return -1 }
        if !process.isRunning {
            return process.terminationStatus
        }

        return await withCheckedContinuation { continuation in
            process.terminationHandler = { terminatedProcess in
                terminatedProcess.terminationHandler = nil
                continuation.resume(returning: terminatedProcess.terminationStatus)
            }
        }
    }

    @MainActor
    private func resolveCompletedOutputURL(fallbackDirectory: URL) -> URL? {
        if let detectedOutputURL, isRegularFile(detectedOutputURL) {
            return detectedOutputURL.standardizedFileURL
        }

        let searchAnchorDate = downloadStartedAt?.addingTimeInterval(-5)
        return newestRegularFile(in: fallbackDirectory, modifiedAfter: searchAnchorDate)
    }

    private func newestRegularFile(in directory: URL, modifiedAfter anchorDate: Date?) -> URL? {
        let keys: [URLResourceKey] = [.isRegularFileKey, .contentModificationDateKey]
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return nil
        }

        var newestCandidate: (url: URL, date: Date)?
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: Set(keys)),
                  values.isRegularFile == true else {
                continue
            }

            let modifiedDate = values.contentModificationDate ?? .distantPast
            if let anchorDate, modifiedDate < anchorDate {
                continue
            }

            if newestCandidate == nil || modifiedDate > newestCandidate!.date {
                newestCandidate = (fileURL, modifiedDate)
            }
        }

        return newestCandidate?.url.standardizedFileURL
    }

    private func isRegularFile(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
    }

    private func existingFilePathIfAny(in line: String) -> String? {
        guard line.hasPrefix("/") else { return nil }
        let candidatePath = String(line.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true).first ?? "")
        let url = URL(fileURLWithPath: candidatePath)
        return isRegularFile(url) ? candidatePath : nil
    }

    private func captureFirstGroup(from regex: NSRegularExpression, in line: String) -> String? {
        guard let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let range = Range(match.range(at: 1), in: line) else {
            return nil
        }
        return String(line[range])
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
                .filter { record in
                    let url = URL(fileURLWithPath: record.filePath)
                    return (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
                }
                .sorted { $0.downloadedAt > $1.downloadedAt }
            lastError = nil
        } catch {
            records = []
            lastError = "Could not load MacYT download history."
        }
    }

    func recordDownload(at fileURL: URL, sourceURL: String?) {
        let standardizedURL = fileURL.standardizedFileURL
        guard (try? standardizedURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else {
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
