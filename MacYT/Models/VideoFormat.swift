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

    func estimatedSizeBytes(duration: Double?) -> Int64? {
        if let sizeBytes {
            return sizeBytes
        }

        guard let duration, duration > 0, let tbr, tbr > 0 else {
            return nil
        }

        let bytes = duration * (tbr * 1000) / 8
        return Int64(bytes.rounded())
    }
    
    var humanFileSize: String {
        guard let size = sizeBytes else { return "Unknown" }
        let mb = Double(size) / 1024 / 1024
        return String(format: "%.1f MB", mb)
    }

    func humanFileSize(duration: Double?) -> String {
        guard let size = estimatedSizeBytes(duration: duration) else { return "Unknown" }

        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.isAdaptive = true

        let label = formatter.string(fromByteCount: size)
        return sizeBytes == nil ? "~\(label)" : label
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

    var displayContainer: String {
        ext.uppercased()
    }
}
