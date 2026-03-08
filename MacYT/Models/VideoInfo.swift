import Foundation

struct VideoInfo: Codable {
    let id: String
    let title: String
    let description: String?
    let thumbnail: String?
    let duration: Double?
    let viewCount: Int?
    let uploadDate: String?
    
    let uploader: String?
    let uploaderUrl: String?
    let channel: String?
    
    let formats: [VideoFormat]
    let requestedFormats: [VideoFormat]?
    
    struct Chapter: Codable {
        let title: String
        let startTime: Double
        let endTime: Double
    }
    let chapters: [Chapter]?
    
    let subtitles: [String: [Subtitle]]?
    let automaticCaptions: [String: [Subtitle]]?
    
    struct Subtitle: Codable {
        let url: String
        let ext: String
        let protocolName: String?
        
        enum CodingKeys: String, CodingKey {
            case url, ext
            case protocolName = "protocol"
        }
    }
    
    var durationString: String {
        guard let duration = duration else { return "Live" }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: duration) ?? ""
    }
    
    var viewCountString: String {
        guard let views = viewCount else { return "No views" }
        if views >= 1_000_000 {
            return String(format: "%.1fM views", Double(views) / 1_000_000)
        } else if views >= 1_000 {
            return String(format: "%.1fK views", Double(views) / 1_000)
        } else {
            return "\(views) views"
        }
    }
}
