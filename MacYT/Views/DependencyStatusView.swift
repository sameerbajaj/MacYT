import SwiftUI

struct DependencyStatusView: View {
    @ObservedObject var viewModel: AppViewModel
    @ObservedObject var checker = DependencyChecker.shared
    
    var body: some View {
        VStack(spacing: MacYTSpacing.xl) {
            Spacer(minLength: MacYTSpacing.xl)

            VStack(alignment: .leading, spacing: MacYTSpacing.xl) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("MacYT Diagnostics")
                            .font(.system(size: 42, weight: .heavy, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [MacYTColors.textPrimary, MacYTColors.accentGradientEnd],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        Text("Before the export studio opens, MacYT verifies the command-line tools it depends on. Right now the blocker is `yt-dlp`. FFmpeg is also checked here so you can diagnose it early.")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(MacYTColors.textSecondary)
                            .frame(maxWidth: 560, alignment: .leading)
                    }

                    Spacer()

                    Image(systemName: "waveform.badge.magnifyingglass")
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundColor(MacYTColors.accentGradientEnd)
                        .padding(18)
                        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                }

                VStack(spacing: MacYTSpacing.md) {
                    DependencyDiagnosticRow(name: "yt-dlp", status: checker.ytdlpStatus)
                    DependencyDiagnosticRow(name: "FFmpeg", status: checker.ffmpegStatus)
                }

                if !checker.coreDependencyInstalled {
                    MacYTInlineBanner(
                        icon: "terminal.fill",
                        title: "Install or repair the required tools",
                        message: checker.unresolvedDependenciesDescription,
                        tint: MacYTColors.warning
                    )

                    HStack(spacing: MacYTSpacing.md) {
                        commandChip(command: "brew install yt-dlp ffmpeg")

                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString("brew install yt-dlp ffmpeg", forType: .string)
                        } label: {
                            Image(systemName: "doc.on.clipboard.fill")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(MacYTColors.textPrimary)
                                .frame(width: 48, height: 48)
                                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack(spacing: MacYTSpacing.md) {
                    GradientButton(
                        title: viewModel.appState == .checkingDeps ? "Checking…" : "Re-check tools",
                        icon: "arrow.clockwise",
                        isLoading: viewModel.appState == .checkingDeps
                    ) {
                        viewModel.recheckDeps()
                    }

                    if checker.ffmpegStatus.isBroken {
                        commandChip(command: "brew upgrade ffmpeg x265")
                    }
                }
            }
            .padding(MacYTSpacing.xxxl)
            .frame(maxWidth: 760)
            .macYTCard()

            Spacer(minLength: MacYTSpacing.xl)
        }
        .padding(.horizontal, MacYTSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func commandChip(command: String) -> some View {
        Text(command)
            .font(.system(size: 13, weight: .semibold, design: .monospaced))
            .foregroundColor(MacYTColors.textPrimary)
            .padding(.horizontal, MacYTSpacing.lg)
            .padding(.vertical, MacYTSpacing.md)
            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
    }
}

private struct DependencyDiagnosticRow: View {
    let name: String
    let status: DependencyStatus
    
    var body: some View {
        VStack(alignment: .leading, spacing: MacYTSpacing.sm) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(MacYTColors.textPrimary)

                    Text(statusSummary)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(MacYTColors.textSecondary)
                }

                Spacer()

                StatusBadge(status: status, name: name)
            }

            if let detail = status.detail, !detail.isEmpty {
                Text(detail)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(MacYTColors.textTertiary)
                    .lineLimit(3)
            }
        }
        .padding(MacYTSpacing.lg)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: MacYTCornerRadius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: MacYTCornerRadius.large, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private var statusSummary: String {
        switch status {
        case .installed:
            return "Installed and ready to launch."
        case .broken:
            return "Found on disk, but macOS could not run it successfully."
        case .missing:
            return "Not found in Homebrew, system folders, or your login shell path."
        case .checking:
            return "Scanning common install locations now."
        }
    }
}
