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
    
    init() {
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

        guard DependencyChecker.shared.ffmpegStatus.isInstalled else {
            errorMessage = DependencyChecker.shared.ffmpegWarningText
            appState = .showingFormats
            return
        }

        guard !urlText.isEmpty else { return }
        
        appState = .downloading
        errorMessage = nil
        let formatId = effectiveFormatIdForCurrentMode()
        
        Task {
            await downloadManager.startDownload(url: urlText, formatId: formatId, options: downloadOptions)
             
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

        return formats.first(where: { !$0.isAudioOnly && !$0.isVideoOnly })?.formatId
            ?? formats.first(where: { !$0.isAudioOnly })?.formatId
            ?? formats.first?.formatId
    }

    private func effectiveFormatIdForCurrentMode() -> String? {
        guard !formats.isEmpty else { return selectedFormatId }

        if downloadOptions.extractAudio {
            return nil
        }

        if let selectedFormatId,
           let selected = formats.first(where: { $0.formatId == selectedFormatId }),
           !selected.isAudioOnly {
            return selected.formatId
        }

        return formats.first(where: { !$0.isAudioOnly && !$0.isVideoOnly })?.formatId
            ?? formats.first(where: { !$0.isAudioOnly })?.formatId
            ?? selectedFormatId
    }
}
