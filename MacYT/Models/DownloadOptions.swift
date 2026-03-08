import Foundation
import Combine

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
    @Published var audioQuality: Int = 0 // 0 is best
    
    @Published var splitChapters: Bool = false
    @Published var outputDirectory: URL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
    @Published var filenameTemplate: String = "%(title)s.%(ext)s"
    
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
            flags.append(contentsOf: ["--audio-quality", "\(audioQuality)"])
        }
        
        if splitChapters {
            flags.append("--split-chapters")
        }
        
        return flags
    }
}
