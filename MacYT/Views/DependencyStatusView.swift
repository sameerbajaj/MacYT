import SwiftUI

struct DependencyStatusView: View {
    @ObservedObject var viewModel: AppViewModel
    @ObservedObject var checker = DependencyChecker.shared
    var onDismiss: (() -> Void)? = nil
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: MacYTSpacing.xl) {
                Spacer(minLength: MacYTSpacing.md)

                VStack(alignment: .leading, spacing: MacYTSpacing.xl) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("MacYT Diagnostics")
                                .font(.system(size: 38, weight: .heavy, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [MacYTColors.textPrimary, MacYTColors.accentGradientEnd],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )

                            Text(diagnosticSubtitle)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(MacYTColors.textSecondary)
                                .frame(maxWidth: 560, alignment: .leading)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: MacYTSpacing.md) {
                            if let onDismiss {
                                Button("Done") {
                                    onDismiss()
                                }
                                .buttonStyle(.plain)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(MacYTColors.accentGradientEnd)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(MacYTColors.accentGradientEnd.opacity(0.14), in: Capsule(style: .continuous))
                            }

                            Image(systemName: "waveform.badge.magnifyingglass")
                                .font(.system(size: 38, weight: .semibold))
                                .foregroundColor(MacYTColors.accentGradientEnd)
                                .padding(16)
                                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        }
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
                .padding(MacYTSpacing.xxl)
                .frame(maxWidth: 760)
                .macYTCard()

                Spacer(minLength: MacYTSpacing.md)
            }
            .padding(.horizontal, MacYTSpacing.xl)
            .padding(.vertical, MacYTSpacing.lg)
            .frame(maxWidth: .infinity)
        }
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

    private var diagnosticSubtitle: String {
        if !checker.coreDependencyInstalled {
            return "MacYT requires yt-dlp to inspect links and download media. Install it below to get started. FFmpeg is also checked for high-quality audio and video merging."
        } else if !checker.allRequiredInstalled {
            return "yt-dlp is installed and ready. FFmpeg was not detected or needs repair. FFmpeg is required for high-resolution stream merging and audio extraction."
        } else {
            return "All dependencies are installed and operational. You are ready to inspect and export media."
        }
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
