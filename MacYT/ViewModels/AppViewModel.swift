import SwiftUI
import Combine

enum AppState: Equatable {
    case checkingDeps
    case ready
    case fetchingInfo
    case checkingError(String)
    case showingFormats
    case downloading
    case completed
}

@MainActor
class AppViewModel: ObservableObject {
    @Published var appState: AppState = .checkingDeps
    @Published var urlText: String = ""
    @Published var videoInfo: VideoInfo?
    @Published var formats: [VideoFormat] = []
    @Published var selectedFormatId: String? = nil
    @Published var errorMessage: String? = nil
    
    @Published var downloadOptions = DownloadOptions()
    
    var ytdlpService = YTDLPService.shared
    var downloadManager = DownloadManager()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        bindNestedObservableObjects()

        Task {
            await DependencyChecker.shared.checkAll()
            updateAppStateAfterDependencyCheck()
        }
    }
    
    func recheckDeps() {
        appState = .checkingDeps
        Task {
            await DependencyChecker.shared.checkAll()
            updateAppStateAfterDependencyCheck()
        }
    }
    
    func fetchVideoInfo() {
        guard DependencyChecker.shared.coreDependencyInstalled else {
            let message = "yt-dlp is required before MacYT can fetch video information."
            errorMessage = message
            appState = .checkingError(message)
            return
        }

        let sanitizedURL = urlText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !sanitizedURL.isEmpty, let url = URL(string: sanitizedURL), url.scheme != nil else {
            errorMessage = "Invalid URL"
            return
        }
        urlText = sanitizedURL
        
        errorMessage = nil
        appState = .fetchingInfo
        videoInfo = nil
        formats = []
        
        Task {
            do {
                let info = try await ytdlpService.fetchVideoInfo(url: sanitizedURL)
                self.videoInfo = info
                if let requestFormats = info.requestedFormats, !requestFormats.isEmpty {
                    var filtered = info.formats.filter { f in
                        f.resolution != "audio only" || requestFormats.contains(where: { $0.formatId == f.formatId })
                    }
                    if filtered.isEmpty { filtered = info.formats }
                    self.formats = filtered.sorted { ($0.tbr ?? 0) > ($1.tbr ?? 0) }
                } else {
                    self.formats = info.formats.sorted { ($0.tbr ?? 0) > ($1.tbr ?? 0) }
                }
                
                self.selectedFormatId = self.defaultFormatID()
                self.appState = .showingFormats
                
            } catch {
                self.errorMessage = error.localizedDescription
                self.appState = .ready
            }
        }
    }
    
    func pasteURL() {
        if let str = NSPasteboard.general.string(forType: .string) {
            urlText = str.trimmingCharacters(in: .whitespacesAndNewlines)
            fetchVideoInfo()
        }
    }
    
    func startDownload() {
        guard DependencyChecker.shared.coreDependencyInstalled else {
            let message = "yt-dlp is required before you can start a download."
            errorMessage = message
            appState = .checkingError(message)
            return
        }

        guard !currentSelectionRequiresFFmpeg || DependencyChecker.shared.ffmpegStatus.isInstalled else {
            errorMessage = ffmpegRequirementMessage
            appState = .showingFormats
            return
        }

        guard !urlText.isEmpty else { return }
        
        appState = .downloading
        errorMessage = nil
        let formatExpression = effectiveFormatExpressionForCurrentMode()
        let requiresMerge = currentSelectionNeedsMergeStep
        
        Task {
            await downloadManager.startDownload(
                url: urlText,
                formatExpression: formatExpression,
                requiresMerge: requiresMerge,
                options: downloadOptions
            )
             
            if case .completed = downloadManager.status {
                appState = .completed
            } else if case .failed(let err) = downloadManager.status {
                errorMessage = err
                appState = .showingFormats
            }
        }
    }
    
    func cancelDownload() {
        downloadManager.cancelDownload()
        appState = .showingFormats
    }

    func refreshSelectionForCurrentMode() {
        guard !formats.isEmpty else {
            selectedFormatId = nil
            return
        }

        if downloadOptions.extractAudio {
            selectedFormatId = nil
            return
        }

        if let selectedFormatId,
           let selected = formats.first(where: { $0.formatId == selectedFormatId }),
           !selected.isAudioOnly {
            return
        }

        selectedFormatId = defaultFormatID()
    }
    
    func reset() {
        urlText = ""
        videoInfo = nil
        formats = []
        selectedFormatId = nil
        errorMessage = nil
        appState = .ready
        downloadManager.status = .idle
    }

    private func bindNestedObservableObjects() {
        downloadOptions.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        downloadManager.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    private func updateAppStateAfterDependencyCheck() {
        if DependencyChecker.shared.coreDependencyInstalled {
            appState = .ready
        } else {
            appState = .checkingError("yt-dlp is required to launch MacYT. Install or repair it, then re-check.")
        }
    }

    private func defaultFormatID() -> String? {
        if downloadOptions.extractAudio {
            return formats.first(where: { $0.isAudioOnly })?.formatId
                ?? formats.first(where: { $0.hasAudio })?.formatId
                ?? formats.first?.formatId
        }

        let preferredFormats = preferredVideoFormatsForCurrentEnvironment()
        return preferredFormats.first?.formatId
            ?? formats.first?.formatId
    }

    private func effectiveFormatExpressionForCurrentMode() -> String? {
        guard !formats.isEmpty else { return selectedFormatId }

        if downloadOptions.extractAudio {
            return nil
        }

        guard let decision = currentVideoSelectionDecision else {
            return preferredVideoFormatsForCurrentEnvironment().first.map { formatExpression(for: $0, needsMerge: $0.isVideoOnly) }
                ?? selectedFormatId
        }

        return formatExpression(for: decision.effectiveFormat, needsMerge: decision.needsMerge)
    }

    private func preferredVideoFormatsForCurrentEnvironment() -> [VideoFormat] {
        let preferredDirectFormats = formats.filter { !$0.isAudioOnly && !$0.isVideoOnly }
        let allVideoFormats = formats.filter { !$0.isAudioOnly }

        if DependencyChecker.shared.ffmpegStatus.isInstalled {
            return sortVideoFormatsForPreference(allVideoFormats)
        }

        return sortVideoFormatsForPreference(preferredDirectFormats.isEmpty ? allVideoFormats : preferredDirectFormats)
    }

    private func sortVideoFormatsForPreference(_ formats: [VideoFormat]) -> [VideoFormat] {
        formats.sorted {
            if ($0.height ?? 0) == ($1.height ?? 0) {
                if $0.hasAudio != $1.hasAudio {
                    return $0.hasAudio && !$1.hasAudio
                }
                return ($0.tbr ?? 0) > ($1.tbr ?? 0)
            }
            return ($0.height ?? 0) > ($1.height ?? 0)
        }
    }

    private func formatExpression(for format: VideoFormat, needsMerge: Bool) -> String {
        guard needsMerge else {
            return format.formatId
        }

        return "\(format.formatId)+bestaudio/\(format.formatId)+ba/\(format.formatId)"
    }

    private func bestDirectFallback(for format: VideoFormat) -> VideoFormat? {
        let targetQuality = format.simplifiedQualityLabel
        return formats
            .filter { !$0.isAudioOnly && !$0.isVideoOnly && $0.simplifiedQualityLabel == targetQuality }
            .sorted {
                if ($0.height ?? 0) == ($1.height ?? 0) {
                    if ($0.fps ?? 0) == ($1.fps ?? 0) {
                        return ($0.tbr ?? 0) > ($1.tbr ?? 0)
                    }
                    return ($0.fps ?? 0) > ($1.fps ?? 0)
                }
                return ($0.height ?? 0) > ($1.height ?? 0)
            }
            .first
    }
}

extension AppViewModel {
    struct VideoSelectionDecision {
        let selectedFormat: VideoFormat
        let effectiveFormat: VideoFormat
        let usedDirectFallback: Bool
        let needsMerge: Bool
    }

    var selectedVideoFormat: VideoFormat? {
        guard !downloadOptions.extractAudio else { return nil }

        if let selectedFormatId,
           let format = formats.first(where: { $0.formatId == selectedFormatId }),
           !format.isAudioOnly {
            return format
        }

        return formats.first(where: { !$0.isAudioOnly && !$0.isVideoOnly })
            ?? formats.first(where: { !$0.isAudioOnly })
    }

    var currentVideoSelectionDecision: VideoSelectionDecision? {
        guard !downloadOptions.extractAudio,
              let selected = selectedVideoFormat else {
            return nil
        }

        guard selected.isVideoOnly else {
            return VideoSelectionDecision(
                selectedFormat: selected,
                effectiveFormat: selected,
                usedDirectFallback: false,
                needsMerge: false
            )
        }

        if let directFallback = bestDirectFallback(for: selected) {
            return VideoSelectionDecision(
                selectedFormat: selected,
                effectiveFormat: directFallback,
                usedDirectFallback: true,
                needsMerge: false
            )
        }

        return VideoSelectionDecision(
            selectedFormat: selected,
            effectiveFormat: selected,
            usedDirectFallback: false,
            needsMerge: true
        )
    }

    var selectedDirectFallbackFormat: VideoFormat? {
        guard let decision = currentVideoSelectionDecision, decision.usedDirectFallback else {
            return nil
        }
        return decision.effectiveFormat
    }

    var currentSelectionNeedsMergeStep: Bool {
        currentVideoSelectionDecision?.needsMerge == true
    }

    var currentSelectionRequiresFFmpeg: Bool {
        if downloadOptions.extractAudio {
            return true
        }

        return currentSelectionNeedsMergeStep
    }

    var ffmpegRequirementMessage: String {
        if downloadOptions.extractAudio {
            return DependencyChecker.shared.ffmpegWarningText ?? "FFmpeg is required for audio extraction."
        }

        guard let decision = currentVideoSelectionDecision else {
            return DependencyChecker.shared.ffmpegWarningText ?? "FFmpeg is required for this export."
        }

        if decision.needsMerge {
            return "\(decision.selectedFormat.simplifiedQualityLabel) needs FFmpeg so MacYT can merge the video stream with audio."
        }

        return DependencyChecker.shared.ffmpegWarningText ?? "FFmpeg is required for this export."
    }

    var selectedQualitySummary: String {
        if downloadOptions.extractAudio {
            return "\(downloadOptions.audioFormat.uppercased()) • \(downloadOptions.audioBitrate.label)"
        }

        guard let decision = currentVideoSelectionDecision else {
            return "Auto selection"
        }

        let suffix: String
        if decision.usedDirectFallback {
            suffix = "Direct stream fallback"
        } else if decision.needsMerge {
            suffix = "Merge with audio"
        } else {
            suffix = "Audio included"
        }
        return "\(decision.selectedFormat.simplifiedQualityLabel) • \(suffix)"
    }
}
