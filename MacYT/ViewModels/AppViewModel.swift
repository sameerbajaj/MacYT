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
            if !DependencyChecker.shared.ytdlpStatus.isInstalled {
                appState = .checkingError("yt-dlp missing or broken")
            } else {
                appState = .ready
            }
        }
    }
    
    func recheckDeps() {
        appState = .checkingDeps
        Task {
            await DependencyChecker.shared.checkAll()
            if !DependencyChecker.shared.ytdlpStatus.isInstalled {
                appState = .checkingError("yt-dlp missing or broken")
            } else {
                appState = .ready
            }
        }
    }
    
    func fetchVideoInfo() {
        guard !urlText.isEmpty, let url = URL(string: urlText), url.scheme != nil else {
            errorMessage = "Invalid URL"
            return
        }
        
        errorMessage = nil
        appState = .fetchingInfo
        videoInfo = nil
        formats = []
        
        Task {
            do {
                let info = try await ytdlpService.fetchVideoInfo(url: urlText)
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
                
                // Select best default
                self.selectedFormatId = self.formats.first?.formatId
                self.appState = .showingFormats
                
            } catch {
                self.errorMessage = error.localizedDescription
                self.appState = .ready
            }
        }
    }
    
    func pasteURL() {
        if let str = NSPasteboard.general.string(forType: .string) {
            urlText = str
            fetchVideoInfo()
        }
    }
    
    func startDownload() {
        guard !urlText.isEmpty else { return }
        
        appState = .downloading
        errorMessage = nil
        
        Task {
            await downloadManager.startDownload(url: urlText, formatId: selectedFormatId, options: downloadOptions)
             
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
    
    func reset() {
        urlText = ""
        videoInfo = nil
        formats = []
        selectedFormatId = nil
        errorMessage = nil
        appState = .ready
        downloadManager.status = .idle
    }
}
