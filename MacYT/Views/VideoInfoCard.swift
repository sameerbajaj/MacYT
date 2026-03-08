import SwiftUI

struct VideoInfoCard: View {
    let info: VideoInfo?
    let isLoading: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: MacYTSpacing.lg) {
            if isLoading {
                SkeletonThumbnail()
                SkeletonMetadata()
            } else if let video = info {
                if let urlString = video.thumbnail, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .aspectRatio(16/9, contentMode: .fit)
                        } else if phase.error != nil {
                            Rectangle().fill(Color.gray.opacity(0.3)).aspectRatio(16/9, contentMode: .fit)
                        } else {
                            SkeletonThumbnail()
                        }
                    }
                    .frame(width: 180)
                    .cornerRadius(MacYTCornerRadius.medium)
                } else {
                    Rectangle().fill(Color.gray.opacity(0.3)).aspectRatio(16/9, contentMode: .fit)
                        .frame(width: 180)
                        .cornerRadius(MacYTCornerRadius.medium)
                }
                
                VStack(alignment: .leading, spacing: MacYTSpacing.xs) {
                    Text(video.title)
                        .font(.headline)
                        .foregroundColor(MacYTColors.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "person.circle.fill")
                        Text(video.channel ?? video.uploader ?? "Unknown Channel")
                    }
                    .font(.subheadline)
                    .foregroundColor(MacYTColors.accentGradientStart)
                    .padding(.top, 4)
                    
                    HStack(spacing: MacYTSpacing.md) {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                            Text(video.durationString)
                        }
                        
                        HStack(spacing: 4) {
                            Image(systemName: "eye")
                            Text(video.viewCountString)
                        }
                    }
                    .font(.caption)
                    .foregroundColor(MacYTColors.textSecondary)
                    .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("Enter a URL and click Fetch")
                    .foregroundColor(MacYTColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(MacYTSpacing.lg)
        .macYTCard()
        .padding(.horizontal)
    }
}

private struct SkeletonThumbnail: View {
    var body: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.1))
            .aspectRatio(16/9, contentMode: .fit)
            .frame(width: 180)
            .cornerRadius(MacYTCornerRadius.medium)
            .shimmerEffect()
    }
}

private struct SkeletonMetadata: View {
    var body: some View {
        VStack(alignment: .leading, spacing: MacYTSpacing.md) {
            Rectangle().fill(Color.gray.opacity(0.1)).frame(height: 20).cornerRadius(4)
            Rectangle().fill(Color.gray.opacity(0.1)).frame(height: 20).padding(.trailing, 40).cornerRadius(4)
            
            Rectangle().fill(Color.gray.opacity(0.1)).frame(width: 120, height: 16).cornerRadius(4).padding(.top, 8)
            
            HStack {
                Rectangle().fill(Color.gray.opacity(0.1)).frame(width: 60, height: 14).cornerRadius(4)
                Rectangle().fill(Color.gray.opacity(0.1)).frame(width: 80, height: 14).cornerRadius(4)
            }.padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .shimmerEffect()
    }
}
