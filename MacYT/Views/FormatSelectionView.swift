import SwiftUI

struct FormatSelectionView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var filterMode: Int = 0 // 0: All, 1: Video Only, 2: Audio Only
    
    var body: some View {
        VStack(alignment: .leading, spacing: MacYTSpacing.lg) {
            HStack(alignment: .top) {
                MacYTSectionHeading(
                    eyebrow: "Formats",
                    title: "Choose a stream profile",
                    subtitle: "Pick a muxed export for the smoothest download, or drill into separate video-only and audio-only tracks when you need more control."
                )

                Spacer(minLength: MacYTSpacing.lg)

                Picker("", selection: $filterMode) {
                    Text("Standard").tag(0)
                    Text("Video Only").tag(1)
                    Text("Audio Only").tag(2)
                }
                .pickerStyle(.segmented)
                .frame(width: 280)
            }

            if filteredFormats.isEmpty {
                emptyState
            } else {
                VStack(spacing: MacYTSpacing.sm) {
                    headerRow

                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: MacYTSpacing.sm) {
                            ForEach(filteredFormats) { format in
                                FormatRow(
                                    format: format,
                                    isSelected: viewModel.selectedFormatId == format.formatId
                                ) {
                                    viewModel.selectedFormatId = format.formatId
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .frame(minHeight: 220, maxHeight: 360)
                }
            }
        }
        .padding(MacYTSpacing.xl)
        .macYTCard()
    }

    private var filteredFormats: [VideoFormat] {
        viewModel.formats.filter { format in
            switch filterMode {
            case 1:
                return format.isVideoOnly
            case 2:
                return format.isAudioOnly
            default:
                return !format.isVideoOnly && !format.isAudioOnly
            }
        }
    }

    private var headerRow: some View {
        HStack {
            Text("PROFILE")
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("CODEC")
                .frame(width: 140, alignment: .leading)

            Text("SIZE")
                .frame(width: 90, alignment: .trailing)

            Text("EXT")
                .frame(width: 60, alignment: .trailing)
        }
        .font(.system(size: 11, weight: .bold, design: .rounded))
        .tracking(1.3)
        .foregroundColor(MacYTColors.textTertiary)
        .padding(.horizontal, MacYTSpacing.md)
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

private struct FormatRow: View {
    let format: VideoFormat
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: MacYTSpacing.md) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: MacYTSpacing.sm) {
                        Text(format.displayResolution)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(MacYTColors.textPrimary)

                        if format.isVideoOnly {
                            capsule(label: "Video only", tint: MacYTColors.warning)
                        } else if format.isAudioOnly {
                            capsule(label: "Audio only", tint: MacYTColors.accentGradientEnd)
                        } else {
                            capsule(label: "Muxed", tint: MacYTColors.success)
                        }
                    }

                    Text(format.formatId)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(MacYTColors.textTertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(format.displayCodec)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(MacYTColors.textSecondary)
                    .frame(width: 140, alignment: .leading)

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

    private func capsule(label: String, tint: Color) -> some View {
        Text(label)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundColor(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint.opacity(0.14), in: Capsule(style: .continuous))
    }
}
