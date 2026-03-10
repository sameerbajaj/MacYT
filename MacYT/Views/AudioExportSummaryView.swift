import SwiftUI

struct AudioExportSummaryView: View {
    @ObservedObject var options: DownloadOptions
    let formats: [VideoFormat]
    let duration: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: MacYTSpacing.lg) {
            MacYTSectionHeading(
                eyebrow: "Audio",
                title: "Simple audio export",
                subtitle: "MacYT will still export your chosen audio format, but the source list below now stays audio-only so you are not staring at irrelevant MP4 video variants."
            )

            VStack(alignment: .leading, spacing: MacYTSpacing.md) {
                HStack(spacing: MacYTSpacing.sm) {
                    summaryChip(icon: "music.note", label: options.audioFormat.uppercased())
                    summaryChip(icon: "dial.high.fill", label: options.audioBitrate.label)
                    summaryChip(icon: "arrow.trianglehead.2.clockwise", label: "Auto source")
                }

                MacYTInlineBanner(
                    icon: "waveform.circle.fill",
                    title: "Audio sources only",
                    message: "These are the best source audio streams yt-dlp reported for this video. MacYT picks from these, then converts to your chosen output format.",
                    tint: MacYTColors.accentGradientEnd
                )

                VStack(alignment: .leading, spacing: MacYTSpacing.sm) {
                    Text("Available source audio streams")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .tracking(1.0)
                        .foregroundColor(MacYTColors.textTertiary)

                    if audioFormats.isEmpty {
                        Text("yt-dlp did not expose a dedicated audio-only stream for this media. MacYT will fall back to the best stream that still contains audio.")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(MacYTColors.textSecondary)
                            .padding(MacYTSpacing.lg)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: MacYTCornerRadius.large, style: .continuous))
                    } else {
                        ForEach(audioFormats.prefix(5)) { format in
                            AudioSourceRow(format: format, duration: duration)
                        }
                    }
                }
            }
        }
        .padding(MacYTSpacing.xl)
        .macYTCard()
    }

    private var audioFormats: [VideoFormat] {
        let dedicated = formats.filter(\ .isAudioOnly)
        let fallback = formats.filter(\ .hasAudio)
        let source = dedicated.isEmpty ? fallback : dedicated

        return source.sorted {
            if ($0.tbr ?? 0) == ($1.tbr ?? 0) {
                return $0.estimatedSizeBytes(duration: duration) ?? 0 > $1.estimatedSizeBytes(duration: duration) ?? 0
            }
            return ($0.tbr ?? 0) > ($1.tbr ?? 0)
        }
    }

    private func summaryChip(icon: String, label: String) -> some View {
        MacYTInfoChip(icon: icon, label: label, tint: MacYTColors.textPrimary)
    }
}

private struct AudioSourceRow: View {
    let format: VideoFormat
    let duration: Double?

    var body: some View {
        HStack(spacing: MacYTSpacing.md) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: MacYTSpacing.sm) {
                    Text(format.displayContainer)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(MacYTColors.textPrimary)

                    Text(format.displayCodec.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(MacYTColors.accentGradientEnd)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(MacYTColors.accentGradientEnd.opacity(0.14), in: Capsule(style: .continuous))
                }

                Text("ID \(format.formatId) • \(bitrateLabel)")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(MacYTColors.textTertiary)
            }

            Spacer(minLength: 0)

            Text(format.humanFileSize(duration: duration))
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(MacYTColors.textPrimary)
        }
        .padding(.horizontal, MacYTSpacing.md)
        .padding(.vertical, MacYTSpacing.md)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: MacYTCornerRadius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: MacYTCornerRadius.large, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private var bitrateLabel: String {
        guard let tbr = format.tbr, tbr > 0 else {
            return "bitrate unknown"
        }
        return String(format: "%.0f kbps", tbr)
    }
}
