import SwiftUI

struct FormatSelectionView: View {
    @ObservedObject var viewModel: AppViewModel
    @ObservedObject private var checker = DependencyChecker.shared
    @State private var showAdvancedStreams = false
    @State private var simpleQualityOptionsCache: [VideoQualityOption] = []
    @State private var advancedFormatsCache: [VideoFormat] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: MacYTSpacing.lg) {
            HStack(alignment: .top) {
                MacYTSectionHeading(
                    eyebrow: "Formats",
                    title: "Choose video quality",
                    subtitle: "Start with the clean, recommended video options. Only open the advanced list when you need technical stream variants."
                )

                Spacer(minLength: MacYTSpacing.lg)

                Button(showAdvancedStreams ? "Hide advanced" : "Show advanced") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showAdvancedStreams.toggle()
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(MacYTColors.accentGradientEnd)
            }

            if simpleQualityOptions.isEmpty {
                emptyState
            } else {
                VStack(spacing: MacYTSpacing.sm) {
                    recommendationBanner
                    helperBanner

                    LazyVStack(spacing: MacYTSpacing.sm) {
                        ForEach(simpleQualityOptions) { option in
                            SimpleQualityRow(
                                option: option,
                                duration: viewModel.videoInfo?.duration,
                                isSelected: selectedQualityKey == option.id,
                                ffmpegInstalled: checker.ffmpegStatus.isInstalled
                            ) {
                                viewModel.selectedFormatId = option.representative.formatId
                            }
                        }

                        if showAdvancedStreams && !advancedFormats.isEmpty {
                            VStack(alignment: .leading, spacing: MacYTSpacing.sm) {
                                Text("Advanced stream variants")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .tracking(1.0)
                                    .foregroundColor(MacYTColors.textTertiary)
                                    .padding(.top, MacYTSpacing.md)

                                Text("Full stream details stay here for edge cases: stream IDs, exact dimensions, codecs, and container variants.")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundColor(MacYTColors.textSecondary)

                                ForEach(advancedFormats) { format in
                                    FormatRow(
                                        format: format,
                                        duration: viewModel.videoInfo?.duration,
                                        isSelected: viewModel.selectedFormatId == format.formatId,
                                        emphasis: .technical
                                    ) {
                                        viewModel.selectedFormatId = format.formatId
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(MacYTSpacing.xl)
        .macYTCard()
        .onAppear(perform: rebuildFormatCaches)
        .onChange(of: viewModel.formats) { _, _ in
            rebuildFormatCaches()
        }
    }

    private var simpleQualityOptions: [VideoQualityOption] {
        simpleQualityOptionsCache
    }

    private var advancedFormats: [VideoFormat] {
        advancedFormatsCache
    }

    private var selectedQualityKey: String? {
        viewModel.selectedVideoFormat?.simplifiedQualityLabel
    }

    private var recommendationBanner: some View {
        MacYTInlineBanner(
            icon: "sparkles.tv.fill",
            title: "Pick a quality, not a stream ID",
            message: "MacYT now groups the raw streams into simple quality choices. When a quality already includes audio, it downloads directly. When it does not, MacYT can merge the best audio in the background.",
            tint: MacYTColors.accentGradientEnd
        )
    }

    @ViewBuilder
    private var helperBanner: some View {
        if let decision = viewModel.currentVideoSelectionDecision {
            if decision.usedDirectFallback, let fallback = viewModel.selectedDirectFallbackFormat {
                MacYTInlineBanner(
                    icon: "checkmark.circle.fill",
                    title: "Merge skipped for \(decision.selectedFormat.simplifiedQualityLabel)",
                    message: "A direct \(fallback.displayContainer) stream with audio is available at this quality, so MacYT will use it and avoid FFmpeg merging.",
                    tint: MacYTColors.success
                )
            } else if decision.needsMerge {
                MacYTInlineBanner(
                    icon: checker.ffmpegStatus.isInstalled ? "arrow.triangle.merge" : "exclamationmark.triangle.fill",
                    title: checker.ffmpegStatus.isInstalled ? "Merge needed for \(decision.selectedFormat.simplifiedQualityLabel)" : "FFmpeg needed for \(decision.selectedFormat.simplifiedQualityLabel)",
                    message: checker.ffmpegStatus.isInstalled
                        ? "This quality is only available as video-only, so MacYT will pair it with the best audio track during export."
                        : "This quality comes as a video-only stream. Install or repair FFmpeg before exporting so MacYT can merge in the audio track.",
                    tint: checker.ffmpegStatus.isInstalled ? MacYTColors.warning : MacYTColors.destructive
                )
            } else {
                MacYTInlineBanner(
                    icon: "checkmark.circle.fill",
                    title: "Audio already included",
                    message: "\(decision.selectedFormat.simplifiedQualityLabel) is available as a ready-to-download stream, so MacYT can save it without an extra merge step.",
                    tint: MacYTColors.success
                )
            }
        }
    }

    private func preferredDisplayOrder(for formats: [VideoFormat]) -> [VideoFormat] {
        formats.sorted {
            if ($0.height ?? 0) == ($1.height ?? 0) {
                return ($0.tbr ?? 0) > ($1.tbr ?? 0)
            }
            return ($0.height ?? 0) > ($1.height ?? 0)
        }
    }

    private func representativeFormat(from formats: [VideoFormat]) -> VideoFormat? {
        formats.sorted {
            if $0.isVideoOnly != $1.isVideoOnly {
                return !$0.isVideoOnly && $1.isVideoOnly
            }

            if ($0.height ?? 0) == ($1.height ?? 0) {
                if ($0.fps ?? 0) == ($1.fps ?? 0) {
                    return ($0.tbr ?? 0) > ($1.tbr ?? 0)
                }
                return ($0.fps ?? 0) > ($1.fps ?? 0)
            }

            return ($0.height ?? 0) > ($1.height ?? 0)
        }
        .first
    }

    private func rebuildFormatCaches() {
        let videoFormats = viewModel.formats.filter { !$0.isAudioOnly }
        advancedFormatsCache = preferredDisplayOrder(for: videoFormats)

        let grouped = Dictionary(grouping: videoFormats) { $0.simplifiedQualityLabel }
        simpleQualityOptionsCache = grouped.compactMap { qualityLabel, formats in
            guard let representative = representativeFormat(from: formats) else {
                return nil
            }

            return VideoQualityOption(label: qualityLabel, formats: formats, representative: representative)
        }
        .sorted { lhs, rhs in
            if lhs.sortHeight == rhs.sortHeight {
                return lhs.label > rhs.label
            }
            return lhs.sortHeight > rhs.sortHeight
        }
    }

    private var emptyState: some View {
        VStack(spacing: MacYTSpacing.md) {
            Image(systemName: "rectangle.slash")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(MacYTColors.textTertiary)

            Text("No formats match this view")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(MacYTColors.textPrimary)

            Text("Try another filter mode, or inspect a different source URL.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(MacYTColors.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 220)
        .background(
            RoundedRectangle(cornerRadius: MacYTCornerRadius.large, style: .continuous)
                .fill(Color.white.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: MacYTCornerRadius.large, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}

private enum FormatRowEmphasis {
    case recommended
    case technical
}

private struct VideoQualityOption: Identifiable {
    let label: String
    let formats: [VideoFormat]
    let representative: VideoFormat

    var id: String { label }

    var sortHeight: Int {
        representative.height ?? 0
    }

    var needsAudioMerge: Bool {
        representative.isVideoOnly
    }

    var hasDirectOption: Bool {
        formats.contains(where: { !$0.isVideoOnly })
    }

    var summaryText: String {
        if representative.isVideoOnly {
            return hasDirectOption
                ? "Best quality uses a separate audio track, but a direct stream also exists in Advanced."
                : "Best source for this quality is video-only, so MacYT will need to add audio during export."
        }

        let details = [representative.displayContainer, representative.fps.map { "\(Int($0)) fps" }]
            .compactMap { $0 }
        return ([representative.shortDimensionLabel] + details).joined(separator: " • ")
    }
}

private struct SimpleQualityRow: View {
    let option: VideoQualityOption
    let duration: Double?
    let isSelected: Bool
    let ffmpegInstalled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: MacYTSpacing.md) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: MacYTSpacing.sm) {
                        Text(option.label)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(MacYTColors.textPrimary)

                        capsule(label: optionBadgeLabel, tint: optionBadgeTint)
                    }

                    Text(option.summaryText)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(MacYTColors.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(option.representative.humanFileSize(duration: duration))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(MacYTColors.textSecondary)
                    .frame(width: 110, alignment: .trailing)

                Text(option.representative.displayContainer)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(isSelected ? MacYTColors.textPrimary : MacYTColors.textSecondary)
                    .frame(width: 60, alignment: .trailing)
            }
            .padding(.horizontal, MacYTSpacing.md)
            .padding(.vertical, MacYTSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: MacYTCornerRadius.large, style: .continuous)
                    .fill(isSelected ? MacYTColors.accentGlow.opacity(0.22) : Color.white.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: MacYTCornerRadius.large, style: .continuous)
                    .stroke(isSelected ? MacYTColors.accentGradientEnd.opacity(0.6) : Color.white.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var optionBadgeLabel: String {
        if option.needsAudioMerge {
            if option.hasDirectOption {
                return "Auto direct"
            }
            return ffmpegInstalled ? "Merge needed" : "FFmpeg needed"
        }

        return "Ready"
    }

    private var optionBadgeTint: Color {
        if option.needsAudioMerge {
            if option.hasDirectOption {
                return MacYTColors.success
            }
            return ffmpegInstalled ? MacYTColors.warning : MacYTColors.destructive
        }

        return MacYTColors.success
    }

    private func capsule(label: String, tint: Color) -> some View {
        Text(label)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundColor(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint.opacity(0.14), in: Capsule(style: .continuous))
    }
}

private struct FormatRow: View {
    let format: VideoFormat
    let duration: Double?
    let isSelected: Bool
    let emphasis: FormatRowEmphasis
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: MacYTSpacing.md) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: MacYTSpacing.sm) {
                        Text(format.displayResolution)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(MacYTColors.textPrimary)

                        if emphasis == .recommended {
                            capsule(label: format.isVideoOnly ? "Video only" : "Recommended", tint: format.isVideoOnly ? MacYTColors.warning : MacYTColors.success)
                        } else if format.isVideoOnly {
                            capsule(label: "Video only", tint: MacYTColors.warning)
                        } else {
                            capsule(label: "Technical", tint: MacYTColors.accentGradientEnd)
                        }
                    }

                    if emphasis == .recommended {
                        Text(formatRecommendationText)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(MacYTColors.textSecondary)
                    } else {
                        Text("ID \(format.formatId) • \(format.displayCodec)")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(MacYTColors.textTertiary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if emphasis == .technical {
                    Text(format.displayCodec)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(MacYTColors.textSecondary)
                        .frame(width: 140, alignment: .leading)
                }

                Text(format.humanFileSize(duration: duration))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(MacYTColors.textSecondary)
                    .frame(width: 110, alignment: .trailing)

                Text(format.ext.uppercased())
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(isSelected ? MacYTColors.textPrimary : MacYTColors.textSecondary)
                    .frame(width: 60, alignment: .trailing)
            }
            .padding(.horizontal, MacYTSpacing.md)
            .padding(.vertical, MacYTSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: MacYTCornerRadius.large, style: .continuous)
                    .fill(isSelected ? MacYTColors.accentGlow.opacity(0.22) : Color.white.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: MacYTCornerRadius.large, style: .continuous)
                    .stroke(isSelected ? MacYTColors.accentGradientEnd.opacity(0.6) : Color.white.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var formatRecommendationText: String {
        if format.isVideoOnly {
            return "Needs a separate audio track during download"
        }

        let details = [format.ext.uppercased(), format.displayCodec, format.fps.map { "\(Int($0)) fps" }]
            .compactMap { $0 }
        return details.joined(separator: " • ")
    }

    private func capsule(label: String, tint: Color) -> some View {
        Text(label)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundColor(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint.opacity(0.14), in: Capsule(style: .continuous))
    }
}
