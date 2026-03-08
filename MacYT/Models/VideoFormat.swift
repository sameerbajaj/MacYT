import Foundation

struct VideoFormat: Codable, Identifiable {
    let formatId: String
    let ext: String
    let resolution: String?
    let width: Int?
    let height: Int?
    let fps: Double?
    let vcodec: String?
    let acodec: String?
    let filesize: Int64?
    let filesizeApprox: Int64?
    let tbr: Double?
    let formatNote: String?
    
    enum CodingKeys: String, CodingKey {
        case formatId = "format_id"
        case ext
        case resolution
        case width, height, fps
        case vcodec, acodec
        case filesize
        case filesizeApprox = "filesize_approx"
        case tbr
        case formatNote = "format_note"
    }
    
    var id: String { formatId }
    
    var isVideoOnly: Bool {
        (vcodec != "none" && vcodec != nil) && (acodec == "none" || acodec == nil)
    }
    
    var isAudioOnly: Bool {
        (vcodec == "none" || vcodec == nil) && (acodec != "none" && acodec != nil)
    }
    
    var hasAudio: Bool {
        acodec != "none" && acodec != nil
    }
    
    var sizeBytes: Int64? {
        filesize ?? filesizeApprox
    }
    
    var humanFileSize: String {
        guard let size = sizeBytes else { return "Unknown" }
        let mb = Double(size) / 1024 / 1024
        return String(format: "%.1f MB", mb)
    }
    
    var displayResolution: String {
        if let res = resolution, res != "audio only" {
            return res
        } else if let h = height {
            return "\(h)p"
        } else if isAudioOnly {
            return "Audio Only"
        }
        return formatNote ?? "Unknown"
    }
    
    var displayCodec: String {
        if isAudioOnly {
            return acodec ?? "Unknown"
        }
        return vcodec ?? "Unknown"
    }
}
