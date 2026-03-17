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
    private var outputFlushTimer: DispatchSourceTimer?
    private var detectedOutputURL: URL?
    private var downloadStartedAt: Date?

    private let outputParsingQueue = DispatchQueue(label: "luminoslabs.MacYT.download-output-parser")
    private var bufferedChunkRemainder: String = ""
    private var pendingConsoleLines: [String] = []
    private var pendingStatus: DownloadStatus?
    private var pendingDetectedOutputURL: URL?
    private var pendingSpeed: String = "0.0B/s"
    private var pendingETA: String = "Unknown"
    
    @MainActor
    func startDownload(url: String, formatExpression: String?, requiresMerge: Bool, options: DownloadOptions) async {
        self.status = .fetching
        self.consoleLogs.removeAll()
        self.currentLine = ""
        self.detectedOutputURL = nil
        self.downloadStartedAt = Date()
        resetOutputParsingState()
        
        var args = options.commandLineFlags(requiresMerge: requiresMerge)
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
            self.enqueueOutputChunk(data)
        }
        errPipe.fileHandleForReading.readabilityHandler = { fh in
            let data = fh.availableData
            if data.isEmpty { return }
            self.enqueueOutputChunk(data)
        }
        
        do {
            try process?.run()
            self.status = .downloading(percent: 0, speed: "0.0B/s", eta: "Unknown")
            startOutputFlushTimer()
            
            let termStatus = await waitForProcessExit()
            
            pipe.fileHandleForReading.readabilityHandler = nil
            errPipe.fileHandleForReading.readabilityHandler = nil
            stopOutputFlushTimer(flushRemainder: true)
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
            stopOutputFlushTimer(flushRemainder: true)
            self.status = .failed(error: error.localizedDescription)
        }
    }
    
    @MainActor
    func cancelDownload() {
        stopOutputFlushTimer(flushRemainder: true)
        process?.terminate()
        process = nil
        status = .cancelled
    }
    
    private let progressRegex = try! NSRegularExpression(pattern: #"\[download\]\s+(\d+(?:\.\d+)?)\%"#)
    private let speedRegex = try! NSRegularExpression(pattern: #"\sat\s+([a-zA-Z0-9.\/]+)"#)
    private let etaRegex = try! NSRegularExpression(pattern: #"\sETA\s+([0-9:]+)"#)
    
    private func enqueueOutputChunk(_ data: Data) {
        let text = String(decoding: data, as: UTF8.self)
        outputParsingQueue.async {
            self.processOutputChunk(text)
        }
    }

    private func processOutputChunk(_ chunk: String) {
        let combined = bufferedChunkRemainder + chunk.replacingOccurrences(of: "\r", with: "\n")
        let lines = combined.components(separatedBy: .newlines)
        let hasTrailingNewline = combined.hasSuffix("\n")

        if hasTrailingNewline {
            bufferedChunkRemainder = ""
        } else {
            bufferedChunkRemainder = lines.last ?? ""
        }

        let completeLines = hasTrailingNewline ? lines : lines.dropLast()
        for rawLine in completeLines {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }
            pendingConsoleLines.append(line)
            updatePendingStatus(from: line)
            if let detectedURL = captureOutputLocation(from: line) {
                pendingDetectedOutputURL = detectedURL
            }
        }
    }

    private func updatePendingStatus(from line: String) {
        if line.contains("[Merger]") || line.contains("[ExtractAudio]") {
            pendingStatus = .postProcessing
            return
        }

        guard let match = progressRegex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let pctRange = Range(match.range(at: 1), in: line),
              let pct = Double(line[pctRange]) else {
            return
        }

        if let speed = captureFirstGroup(from: speedRegex, in: line) {
            pendingSpeed = speed
        }
        if let eta = captureFirstGroup(from: etaRegex, in: line) {
            pendingETA = eta
        }

        let progress = max(0, min(1, pct / 100.0))
        if progress >= 1 && !line.contains("ETA") {
            pendingStatus = .postProcessing
        } else {
            pendingStatus = .downloading(percent: progress, speed: pendingSpeed, eta: pendingETA)
        }
    }

    @MainActor
    private func startOutputFlushTimer() {
        stopOutputFlushTimer(flushRemainder: false)

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: .milliseconds(120), leeway: .milliseconds(30))
        timer.setEventHandler { [weak self] in
            self?.flushPendingOutput(includeRemainder: false)
        }
        timer.resume()
        outputFlushTimer = timer
    }

    @MainActor
    private func stopOutputFlushTimer(flushRemainder: Bool) {
        outputFlushTimer?.cancel()
        outputFlushTimer = nil
        if flushRemainder {
            flushPendingOutput(includeRemainder: true)
        }
    }

    @MainActor
    private func flushPendingOutput(includeRemainder: Bool) {
        let snapshot = outputParsingQueue.sync { () -> (lines: [String], status: DownloadStatus?, outputURL: URL?) in
            if includeRemainder {
                let remainder = bufferedChunkRemainder.trimmingCharacters(in: .whitespacesAndNewlines)
                if !remainder.isEmpty {
                    pendingConsoleLines.append(remainder)
                    updatePendingStatus(from: remainder)
                    if let detectedURL = captureOutputLocation(from: remainder) {
                        pendingDetectedOutputURL = detectedURL
                    }
                }
                bufferedChunkRemainder = ""
            }

            let lines = pendingConsoleLines
            let status = pendingStatus
            let outputURL = pendingDetectedOutputURL
            pendingConsoleLines.removeAll(keepingCapacity: true)
            pendingStatus = nil
            pendingDetectedOutputURL = nil
            return (lines, status, outputURL)
        }

        guard !snapshot.lines.isEmpty || snapshot.status != nil || snapshot.outputURL != nil else {
            return
        }

        if !snapshot.lines.isEmpty {
            currentLine = snapshot.lines.last ?? currentLine
            consoleLogs.append(contentsOf: snapshot.lines)
            if consoleLogs.count > 500 {
                consoleLogs.removeFirst(consoleLogs.count - 500)
            }
        }
        if let outputURL = snapshot.outputURL {
            detectedOutputURL = outputURL
        }
        if let status = snapshot.status {
            self.status = status
        }
    }

    private func resetOutputParsingState() {
        outputParsingQueue.sync {
            bufferedChunkRemainder = ""
            pendingConsoleLines.removeAll(keepingCapacity: false)
            pendingStatus = nil
            pendingDetectedOutputURL = nil
            pendingSpeed = "0.0B/s"
            pendingETA = "Unknown"
        }
    }

    private func captureOutputLocation(from line: String) -> URL? {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)

        if let path = existingFilePathIfAny(in: trimmedLine) {
            return URL(fileURLWithPath: path)
        }

        if let path = quotedPath(in: line, prefix: "[Merger] Merging formats into ") {
            return URL(fileURLWithPath: path)
        }

        if let path = plainPath(in: line, prefix: "[ExtractAudio] Destination: ") {
            return URL(fileURLWithPath: path)
        }

        if let path = plainPath(in: line, prefix: "[download] Destination: ") {
            return URL(fileURLWithPath: path)
        }

        return nil
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
