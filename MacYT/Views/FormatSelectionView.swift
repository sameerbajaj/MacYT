import SwiftUI

struct FormatSelectionView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var showAdvancedStreams = false
    
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

            if recommendedFormats.isEmpty {
                emptyState
            } else {
                VStack(spacing: MacYTSpacing.sm) {
                    recommendationBanner

                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: MacYTSpacing.sm) {
                            ForEach(recommendedFormats) { format in
                                FormatRow(
                                    format: format,
                                    isSelected: viewModel.selectedFormatId == format.formatId,
                                    emphasis: .recommended
                                ) {
                                    viewModel.selectedFormatId = format.formatId
                                }
                            }

                            if showAdvancedStreams && !advancedFormats.isEmpty {
                                VStack(alignment: .leading, spacing: MacYTSpacing.sm) {
                                    Text("Advanced stream variants")
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                        .tracking(1.0)
                                        .foregroundColor(MacYTColors.textTertiary)
                                        .padding(.top, MacYTSpacing.md)

                                    ForEach(advancedFormats) { format in
                                        FormatRow(
                                            format: format,
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
                    .frame(minHeight: 280, maxHeight: 520)
                }
            }
        }
        .padding(MacYTSpacing.xl)
        .macYTCard()
    }

    private var recommendedFormats: [VideoFormat] {
        let muxed = viewModel.formats.filter { !$0.isAudioOnly && !$0.isVideoOnly }
        let fallback = viewModel.formats.filter { !$0.isAudioOnly }
        return preferredDisplayOrder(for: muxed.isEmpty ? fallback : muxed)
    }

    private var advancedFormats: [VideoFormat] {
        let recommendedIDs = Set(recommendedFormats.map(\ .formatId))
        return preferredDisplayOrder(for: viewModel.formats.filter { !recommendedIDs.contains($0.formatId) && !$0.isAudioOnly })
    }

    private var recommendationBanner: some View {
        MacYTInlineBanner(
            icon: "sparkles.tv.fill",
            title: "Recommended for most downloads",
            message: "These options already include audio when available, so you usually do not need to think about separate stream pieces.",
            tint: MacYTColors.accentGradientEnd
        )
    }

    private func preferredDisplayOrder(for formats: [VideoFormat]) -> [VideoFormat] {
        formats.sorted {
            if ($0.height ?? 0) == ($1.height ?? 0) {
                return ($0.tbr ?? 0) > ($1.tbr ?? 0)
            }
            return ($0.height ?? 0) > ($1.height ?? 0)
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

private struct FormatRow: View {
    let format: VideoFormat
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

                Text(format.humanFileSize)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(MacYTColors.textSecondary)
                    .frame(width: 90, alignment: .trailing)

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
