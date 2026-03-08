import Foundation
import Combine

enum AudioBitratePreset: String, CaseIterable, Identifiable {
    case best
    case kb320
    case kb256
    case kb192
    case kb128

    var id: String { rawValue }

    var label: String {
        switch self {
        case .best: return "Best"
        case .kb320: return "320 kbps"
        case .kb256: return "256 kbps"
        case .kb192: return "192 kbps"
        case .kb128: return "128 kbps"
        }
    }

    var description: String {
        switch self {
        case .best: return "Use the highest quality conversion available"
        case .kb320: return "Large files, highest MP3-style bitrate"
        case .kb256: return "High quality for music and podcasts"
        case .kb192: return "Balanced size and quality"
        case .kb128: return "Smaller files for voice-first listening"
        }
    }

    var ytDLPValue: String {
        switch self {
        case .best: return "0"
        case .kb320: return "320K"
        case .kb256: return "256K"
        case .kb192: return "192K"
        case .kb128: return "128K"
        }
    }
}

class DownloadOptions: ObservableObject {
    @Published var embedMetadata: Bool = true
    @Published var embedChapters: Bool = true
    @Published var embedThumbnail: Bool = true
    
    @Published var writeSubs: Bool = false
    @Published var writeAutoSubs: Bool = false
    @Published var subLanguage: String = "en"
    @Published var convertSubsToEmber: Bool = false // e.g. srt, vtt
    @Published var convertSubsFormat: String = "srt"
    
    @Published var sponsorBlock: Bool = false
    @Published var sponsorBlockAction: String = "mark" // mark, remove
    
    @Published var extractAudio: Bool = false
    @Published var audioFormat: String = "mp3"
    @Published var audioBitrate: AudioBitratePreset = .best
    
    @Published var splitChapters: Bool = false
    @Published var outputDirectory: URL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
    @Published var filenameTemplate: String = "%(title)s.%(ext)s"

    var exportModeTitle: String {
        extractAudio ? "Audio export" : "Video export"
    }
    
    func commandLineFlags() -> [String] {
        var flags: [String] = []
        
        flags.append(contentsOf: ["--paths", outputDirectory.path])
        flags.append(contentsOf: ["-o", filenameTemplate])
        
        if embedMetadata { flags.append("--embed-metadata") }
        if embedChapters { flags.append("--embed-chapters") }
        if embedThumbnail {
            flags.append("--embed-thumbnail")
            flags.append("--write-thumbnail") // required to embed
        }
        
        if writeSubs { flags.append("--write-subs") }
        if writeAutoSubs { flags.append("--write-auto-subs") }
        if writeSubs || writeAutoSubs {
            flags.append(contentsOf: ["--sub-langs", subLanguage])
            if convertSubsToEmber {
                flags.append(contentsOf: ["--convert-subs", convertSubsFormat])
            }
        }
        
        if sponsorBlock {
            if sponsorBlockAction == "mark" {
                flags.append(contentsOf: ["--sponsorblock-mark", "all"])
            } else {
                flags.append(contentsOf: ["--sponsorblock-remove", "all"])
            }
        }
        
        if extractAudio {
            flags.append("-x")
            flags.append(contentsOf: ["--audio-format", audioFormat])
            flags.append(contentsOf: ["--audio-quality", audioBitrate.ytDLPValue])
        }
        
        if splitChapters {
            flags.append("--split-chapters")
        }
        
        return flags
    }
}
