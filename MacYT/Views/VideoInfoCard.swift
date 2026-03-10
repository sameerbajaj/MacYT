import SwiftUI

struct VideoInfoCard: View {
    let info: VideoInfo?
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: MacYTSpacing.lg) {
            MacYTSectionHeading(
                eyebrow: "Preview",
                title: info == nil ? "Media slate" : "Loaded media snapshot",
                subtitle: info == nil
                    ? "Once you inspect a URL, its artwork, publisher, runtime, and available output profile will appear here."
                    : "Review the source before choosing a stream or exporting an audio-first version."
            )

            if isLoading {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: MacYTSpacing.xl) {
                        SkeletonThumbnail()
                        SkeletonMetadata()
                    }

                    VStack(alignment: .leading, spacing: MacYTSpacing.lg) {
                        SkeletonThumbnail()
                        SkeletonMetadata()
                    }
                }
            } else if let video = info {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: MacYTSpacing.xl) {
                        thumbnail(for: video)
                        metadata(for: video)
                    }

                    VStack(alignment: .leading, spacing: MacYTSpacing.lg) {
                        thumbnail(for: video)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        metadata(for: video)
                    }
                }
            } else {
                emptyState
            }
        }
        .padding(MacYTSpacing.xl)
        .macYTCard()
    }

    private func metadata(for video: VideoInfo) -> some View {
        VStack(alignment: .leading, spacing: MacYTSpacing.md) {
            Text(video.title)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(MacYTColors.textPrimary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)

            HStack(spacing: 10) {
                Image(systemName: "person.crop.square.fill")
                Text(video.channel ?? video.uploader ?? "Unknown publisher")
            }
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundColor(MacYTColors.accentGradientEnd)

            if let description = video.description, !description.isEmpty {
                Text(description)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(MacYTColors.textSecondary)
                    .lineLimit(5)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: MacYTSpacing.sm) {
                    MacYTInfoChip(icon: "clock.fill", label: video.durationString.isEmpty ? "Unknown length" : video.durationString, tint: MacYTColors.textPrimary)
                    MacYTInfoChip(icon: "eye.fill", label: video.viewCountString)
                    MacYTInfoChip(icon: "rectangle.stack.fill.badge.play", label: "\(video.formats.count) formats")
                }

                VStack(alignment: .leading, spacing: MacYTSpacing.sm) {
                    MacYTInfoChip(icon: "clock.fill", label: video.durationString.isEmpty ? "Unknown length" : video.durationString, tint: MacYTColors.textPrimary)
                    MacYTInfoChip(icon: "eye.fill", label: video.viewCountString)
                    MacYTInfoChip(icon: "rectangle.stack.fill.badge.play", label: "\(video.formats.count) formats")
                }
            }

            if let uploadDate = video.uploadDate, !uploadDate.isEmpty {
                Text("Published · \(uploadDate)")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(MacYTColors.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func thumbnail(for video: VideoInfo) -> some View {
        ZStack(alignment: .bottomLeading) {
            if let urlString = video.thumbnail, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .aspectRatio(16 / 9, contentMode: .fill)
                    } else if phase.error != nil {
                        Rectangle().fill(Color.white.opacity(0.08))
                    } else {
                        SkeletonThumbnail()
                    }
                }
            } else {
                Rectangle()
                    .fill(Color.white.opacity(0.08))
            }

            LinearGradient(
                colors: [.clear, Color.black.opacity(0.72)],
                startPoint: .center,
                endPoint: .bottom
            )

            HStack(spacing: MacYTSpacing.sm) {
                Image(systemName: "play.rectangle.fill")
                Text(video.durationString.isEmpty ? "Preview ready" : video.durationString)
            }
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .frame(width: 340, height: 192)
        .clipShape(RoundedRectangle(cornerRadius: MacYTCornerRadius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: MacYTCornerRadius.large, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: MacYTSpacing.md) {
            Image(systemName: "sparkles.tv.fill")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(MacYTColors.accentGradientEnd)

            Text("No media loaded yet")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(MacYTColors.textPrimary)

            Text("Paste a link above to load the channel, title, artwork, and the format matrix for that video.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(MacYTColors.textSecondary)
                .frame(maxWidth: 420, alignment: .leading)

            HStack(spacing: MacYTSpacing.sm) {
                MacYTInfoChip(icon: "highlighter", label: "Format breakdown")
                MacYTInfoChip(icon: "music.note.house.fill", label: "Audio extraction")
                MacYTInfoChip(icon: "folder.badge.gearshape", label: "Export controls")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SkeletonThumbnail: View {
    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(width: 340, height: 192)
            .cornerRadius(MacYTCornerRadius.large)
            .shimmerEffect()
    }
}

private struct SkeletonMetadata: View {
    var body: some View {
        VStack(alignment: .leading, spacing: MacYTSpacing.md) {
            Rectangle().fill(Color.white.opacity(0.08)).frame(height: 24).cornerRadius(8)
            Rectangle().fill(Color.white.opacity(0.08)).frame(height: 24).padding(.trailing, 40).cornerRadius(8)

            Rectangle().fill(Color.white.opacity(0.08)).frame(width: 170, height: 18).cornerRadius(6).padding(.top, 8)

            HStack {
                Rectangle().fill(Color.white.opacity(0.08)).frame(width: 90, height: 34).cornerRadius(17)
                Rectangle().fill(Color.white.opacity(0.08)).frame(width: 110, height: 34).cornerRadius(17)
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .shimmerEffect()
    }
}
