import SwiftUI

struct AudioExportSummaryView: View {
    @ObservedObject var options: DownloadOptions

    var body: some View {
        VStack(alignment: .leading, spacing: MacYTSpacing.lg) {
            MacYTSectionHeading(
                eyebrow: "Audio",
                title: "Simple audio export",
                subtitle: "No stream list needed here. MacYT will pull the best available source audio, convert it, and save the finished file in your chosen format."
            )

            VStack(alignment: .leading, spacing: MacYTSpacing.md) {
                HStack(spacing: MacYTSpacing.sm) {
                    summaryChip(icon: "music.note", label: options.audioFormat.uppercased())
                    summaryChip(icon: "dial.high.fill", label: options.audioBitrate.label)
                    summaryChip(icon: "arrow.trianglehead.2.clockwise", label: "Auto source")
                }

                MacYTInlineBanner(
                    icon: "sparkles",
                    title: "Stream details are hidden on purpose",
                    message: "For audio downloads, the app now abstracts away raw YouTube stream variants and focuses on the output you actually care about.",
                    tint: MacYTColors.accentGradientEnd
                )
            }
        }
        .padding(MacYTSpacing.xl)
        .macYTCard()
    }

    private func summaryChip(icon: String, label: String) -> some View {
        MacYTInfoChip(icon: icon, label: label, tint: MacYTColors.textPrimary)
    }
}
