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
    private(set) var currentLine: String = ""
    private(set) var consoleLogs: [String] = []
    private let progressMarker = "[MACYT_PROGRESS]"
    private let debugLogQueue = DispatchQueue(label: "luminoslabs.MacYT.download-debug-log")
    
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
        resetDebugLog()
        writeDebugLog("session.start url=\(url) requiresMerge=\(requiresMerge) extractAudio=\(options.extractAudio)")
        
        var args = options.commandLineFlags(requiresMerge: requiresMerge)
        args.append(contentsOf: [
            "--progress",
            "--newline",
            "--progress-delta", "0.25",
            "--progress-template", "download:\(progressMarker)%(progress._percent_str)s|%(progress._speed_str)s|%(progress._eta_str)s"
        ])
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
        writeDebugLog("process.path \(path)")
        writeDebugLog("process.args \(args.joined(separator: " "))")
        
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
            writeDebugLog("status.publish downloading percent=0 speed=0.0B/s eta=Unknown reason=initial")
            startOutputFlushTimer()
            
            let termStatus = await waitForProcessExit()
            writeDebugLog("process.exit code=\(termStatus)")
            
            pipe.fileHandleForReading.readabilityHandler = nil
            errPipe.fileHandleForReading.readabilityHandler = nil
            stopOutputFlushTimer(flushRemainder: true)
            process = nil
            
            if termStatus == 0 {
                if let resolvedOutputURL = resolveCompletedOutputURL(fallbackDirectory: options.outputDirectory) {
                    DownloadHistoryStore.shared.recordDownload(at: resolvedOutputURL, sourceURL: url)
                    DownloadHistoryStore.shared.refresh()
                    self.status = .completed(filePath: resolvedOutputURL.path)
                    writeDebugLog("status.publish completed path=\(resolvedOutputURL.path)")
                } else {
                    self.status = .failed(error: "Download finished, but MacYT could not locate the exported file.")
                    writeDebugLog("status.publish failed reason=missing_output_file")
                }
            } else if status != .cancelled {
                self.status = .failed(error: "yt-dlp exited with code \(termStatus)")
                writeDebugLog("status.publish failed reason=termination_code_\(termStatus)")
            }
            
        } catch {
            stopOutputFlushTimer(flushRemainder: true)
            self.status = .failed(error: error.localizedDescription)
            writeDebugLog("status.publish failed reason=launch_error message=\(error.localizedDescription)")
        }
    }
    
    @MainActor
    func cancelDownload() {
        stopOutputFlushTimer(flushRemainder: true)
        process?.terminate()
        process = nil
        status = .cancelled
        writeDebugLog("status.publish cancelled")
    }
    
    private func enqueueOutputChunk(_ data: Data) {
        let text = String(decoding: data, as: UTF8.self)
        writeDebugLog("chunk.raw \(debugEscaped(text))")
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
            writeDebugLog("line.raw \(debugEscaped(rawLine))")
            if shouldPersistConsoleLine(line) {
                pendingConsoleLines.append(line)
            }
            updatePendingStatus(from: line)
            if let detectedURL = captureOutputLocation(from: line) {
                pendingDetectedOutputURL = detectedURL
            }
        }

        let partialLine = bufferedChunkRemainder.trimmingCharacters(in: .whitespacesAndNewlines)
        if !partialLine.isEmpty {
            writeDebugLog("line.partial \(debugEscaped(partialLine))")
            updatePendingStatus(from: partialLine)
        }
    }

    private func updatePendingStatus(from line: String) {
        let normalizedLine = sanitizeOutputLine(line)
        writeDebugLog("line.sanitized \(debugEscaped(normalizedLine))")

        guard !normalizedLine.isEmpty else { return }

        if normalizedLine.contains("[Merger]") || normalizedLine.contains("[ExtractAudio]") {
            pendingStatus = .postProcessing
            writeDebugLog("status.pending postProcessing source=postprocess_line")
            return
        }

        if let snapshot = parseStructuredProgressSnapshot(from: normalizedLine) {
            pendingSpeed = snapshot.speed
            pendingETA = snapshot.eta

            let progress = max(0, min(1, snapshot.percent / 100.0))
            writeDebugLog("progress.structured percent=\(snapshot.percent) speed=\(snapshot.speed) eta=\(snapshot.eta)")
            if progress >= 1 && !normalizedLine.contains("ETA") {
                pendingStatus = .postProcessing
                writeDebugLog("status.pending postProcessing source=structured_progress_complete")
            } else {
                pendingStatus = .downloading(percent: progress, speed: pendingSpeed, eta: pendingETA)
                writeDebugLog("status.pending downloading percent=\(progress) speed=\(pendingSpeed) eta=\(pendingETA) source=structured_progress")
            }
            return
        }

        if let snapshot = parseDownloadProgressSnapshot(from: normalizedLine) {
            pendingSpeed = snapshot.speed
            pendingETA = snapshot.eta

            let progress = max(0, min(1, snapshot.percent / 100.0))
            writeDebugLog("progress.fallback percent=\(snapshot.percent) speed=\(snapshot.speed) eta=\(snapshot.eta)")
            if progress >= 1 && !normalizedLine.contains("ETA") {
                pendingStatus = .postProcessing
                writeDebugLog("status.pending postProcessing source=fallback_progress_complete")
            } else {
                pendingStatus = .downloading(percent: progress, speed: pendingSpeed, eta: pendingETA)
                writeDebugLog("status.pending downloading percent=\(progress) speed=\(pendingSpeed) eta=\(pendingETA) source=fallback_progress")
            }
            return
        }

        writeDebugLog("progress.none")
    }

    @MainActor
    private func startOutputFlushTimer() {
        stopOutputFlushTimer(flushRemainder: false)

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: .milliseconds(300), leeway: .milliseconds(75))
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
            if consoleLogs.count > 250 {
                consoleLogs.removeFirst(consoleLogs.count - 250)
            }
        }
        if let outputURL = snapshot.outputURL {
            detectedOutputURL = outputURL
            writeDebugLog("output.detected \(outputURL.path)")
        }
        if let status = snapshot.status {
            if self.status != status {
                self.status = status
                writeDebugLog("status.publish \(describe(status))")
            }
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

    private func shouldPersistConsoleLine(_ line: String) -> Bool {
        let normalizedLine = sanitizeOutputLine(line)
        return !isDownloadProgressTelemetryLine(normalizedLine)
    }

    private func isDownloadProgressTelemetryLine(_ line: String) -> Bool {
        if line.contains(progressMarker) {
            return true
        }
        return line.contains("[download]") && line.contains("%")
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

    private func parseDownloadProgressSnapshot(from line: String) -> DownloadProgressSnapshot? {
        guard let downloadRange = line.range(of: "[download]"),
              let percentIndex = line[downloadRange.lowerBound...].firstIndex(of: "%") else {
            return nil
        }

        let prefix = line[downloadRange.lowerBound..<percentIndex]
        let tokens = prefix.split(whereSeparator: { !$0.isNumber && $0 != "." })
        guard let pctToken = tokens.last,
              let pct = Double(pctToken) else {
            return nil
        }

        let downloadSegment = line[downloadRange.lowerBound...]
        let speedCandidate = extractSpeed(from: String(downloadSegment)) ?? pendingSpeed
        let etaCandidate = extractETA(from: String(downloadSegment)) ?? pendingETA

        return DownloadProgressSnapshot(
            percent: pct,
            speed: normalizeSpeedLabel(speedCandidate),
            eta: normalizeETALabel(etaCandidate)
        )
    }

    private func parseStructuredProgressSnapshot(from line: String) -> DownloadProgressSnapshot? {
        guard let markerRange = line.range(of: progressMarker) else {
            return nil
        }

        let payload = line[markerRange.upperBound...]
        let parts = payload.split(separator: "|", maxSplits: 2, omittingEmptySubsequences: false).map {
            String($0).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard let percentPart = parts.first else { return nil }
        let tokens = percentPart.split(whereSeparator: { !$0.isNumber && $0 != "." })
        guard let percentToken = tokens.last, let percent = Double(percentToken) else {
            return nil
        }

        let speed = parts.count > 1 ? parts[1] : pendingSpeed
        let eta = parts.count > 2 ? parts[2] : pendingETA

        return DownloadProgressSnapshot(
            percent: percent,
            speed: normalizeSpeedLabel(speed),
            eta: normalizeETALabel(eta)
        )
    }

    private func sanitizeOutputLine(_ line: String) -> String {
        stripANSIEscapes(line).replacingOccurrences(of: "\u{00A0}", with: " ")
    }

    private func normalizeSpeedLabel(_ label: String) -> String {
        let cleaned = label.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.isEmpty || cleaned.caseInsensitiveCompare("unknown") == .orderedSame {
            return "Unknown"
        }
        return cleaned
    }

    private func normalizeETALabel(_ label: String) -> String {
        let cleaned = label.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "Unknown" : cleaned
    }

    private func extractSpeed(from line: String) -> String? {
        guard let atRange = line.range(of: " at ") else { return nil }
        let afterAt = line[atRange.upperBound...]
        if let etaRange = afterAt.range(of: " ETA ") {
            return String(afterAt[..<etaRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return String(afterAt).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractETA(from line: String) -> String? {
        guard let etaRange = line.range(of: " ETA ") else { return nil }
        return String(line[etaRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func stripANSIEscapes(_ text: String) -> String {
        var result = ""
        var isEscaping = false

        for character in text {
            if isEscaping {
                if character.isLetter {
                    isEscaping = false
                }
                continue
            }

            if character == "\u{1B}" {
                isEscaping = true
                continue
            }

            result.append(character)
        }

        return result
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

    private func resetDebugLog() {
        debugLogQueue.async {
            guard let url = self.debugLogURL() else { return }
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? Data().write(to: url, options: .atomic)
        }
    }

    private func writeDebugLog(_ message: String) {
        debugLogQueue.async {
            guard let url = self.debugLogURL() else { return }
            let timestamp = ISO8601DateFormatter().string(from: Date())
            let line = "[\(timestamp)] \(message)\n"
            guard let data = line.data(using: .utf8) else { return }

            if !FileManager.default.fileExists(atPath: url.path) {
                try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                FileManager.default.createFile(atPath: url.path, contents: nil)
            }

            do {
                let handle = try FileHandle(forWritingTo: url)
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
                try handle.close()
            } catch {
                return
            }
        }
    }

    private func debugLogURL() -> URL? {
        let appSupport = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return appSupport?
            .appendingPathComponent("MacYT", isDirectory: true)
            .appendingPathComponent("download-debug.log")
    }

    private func debugEscaped(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
    }

    private func describe(_ status: DownloadStatus) -> String {
        switch status {
        case .idle:
            return "idle"
        case .fetching:
            return "fetching"
        case let .downloading(percent, speed, eta):
            return "downloading percent=\(percent) speed=\(speed) eta=\(eta)"
        case .postProcessing:
            return "postProcessing"
        case let .completed(filePath):
            return "completed path=\(filePath)"
        case let .failed(error):
            return "failed error=\(error)"
        case .cancelled:
            return "cancelled"
        }
    }
}

private struct DownloadProgressSnapshot {
    let percent: Double
    let speed: String
    let eta: String
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
