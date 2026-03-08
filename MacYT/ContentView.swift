import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = AppViewModel()
    @ObservedObject private var checker = DependencyChecker.shared
    
    private var shouldShowDependencyScreen: Bool {
        if case .checkingDeps = viewModel.appState {
            return true
        }
        if case .checkingError = viewModel.appState {
            return !checker.coreDependencyInstalled
        }
        return false
    }
    
    var body: some View {
        ZStack {
            MacYTBackgroundView()

            if shouldShowDependencyScreen {
                DependencyStatusView(viewModel: viewModel)
            } else {
                MainAppView(viewModel: viewModel)
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .preferredColorScheme(.dark)
    }
}

struct MainAppView: View {
    @ObservedObject var viewModel: AppViewModel
    @ObservedObject private var checker = DependencyChecker.shared
    
    var body: some View {
        HStack(alignment: .top, spacing: MacYTSpacing.xl) {
            VStack(alignment: .leading, spacing: MacYTSpacing.xl) {
                header

                URLInputBar(viewModel: viewModel)

                if let warning = checker.ffmpegWarningText {
                    MacYTInlineBanner(
                        icon: checker.ffmpegStatus.isBroken ? "wrench.adjustable.fill" : "sparkles.tv.fill",
                        title: checker.ffmpegStatus.isBroken ? "FFmpeg needs repair" : "FFmpeg not found",
                        message: warning,
                        tint: checker.ffmpegStatus.isBroken ? MacYTColors.warning : MacYTColors.accentGradientEnd
                    )
                }

                if let err = viewModel.errorMessage {
                    MacYTInlineBanner(
                        icon: "exclamationmark.triangle.fill",
                        title: "Action needed",
                        message: err,
                        tint: MacYTColors.destructive
                    )
                }

                ScrollView(showsIndicators: false) {
                    VStack(spacing: MacYTSpacing.xl) {
                        VideoInfoCard(
                            info: viewModel.videoInfo,
                            isLoading: viewModel.appState == .fetchingInfo
                        )

                        if viewModel.appState == .showingFormats || viewModel.appState == .downloading || viewModel.appState == .completed {
                            if viewModel.downloadOptions.extractAudio {
                                AudioExportSummaryView(options: viewModel.downloadOptions)
                            } else {
                                FormatSelectionView(viewModel: viewModel)
                            }
                        }
                    }
                    .padding(.bottom, 150)
                }
                .mask(
                    LinearGradient(
                        colors: [.clear, .black, .black, .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            DownloadOptionsPanel(options: viewModel.downloadOptions)
                .padding(.top, MacYTSpacing.xs)
        }
        .padding(.horizontal, MacYTSpacing.xxl)
        .padding(.top, MacYTSpacing.xxl)
        .onChange(of: viewModel.downloadOptions.extractAudio) { _, _ in
            viewModel.refreshSelectionForCurrentMode()
        }
        .overlay(
            VStack {
                Spacer()
                if viewModel.appState == .showingFormats || viewModel.appState == .downloading || viewModel.appState == .completed {
                    DownloadProgressView(viewModel: viewModel)
                        .padding(.horizontal, MacYTSpacing.xxl)
                        .padding(.bottom, MacYTSpacing.xl)
                }
            },
            alignment: .bottom
        )
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: MacYTSpacing.lg) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("MacYT Studio")
                        .font(.system(size: 44, weight: .heavy, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [MacYTColors.textPrimary, MacYTColors.accentGradientEnd],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Text("A broadcast-style workspace for pulling clean media, previewing available formats, and exporting exactly the build you want.")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(MacYTColors.textSecondary)
                        .frame(maxWidth: 560, alignment: .leading)
                }

                Spacer(minLength: MacYTSpacing.lg)

                dependencyStatusMenu
            }

            HStack(spacing: MacYTSpacing.sm) {
                MacYTInfoChip(icon: "film.stack.fill", label: viewModel.videoInfo == nil ? "Awaiting link" : "Media loaded", tint: MacYTColors.accentGradientEnd)
                MacYTInfoChip(icon: viewModel.downloadOptions.extractAudio ? "music.note" : "play.rectangle.fill", label: viewModel.downloadOptions.exportModeTitle)
                MacYTInfoChip(icon: "folder.fill", label: viewModel.downloadOptions.outputDirectory.lastPathComponent)
            }
        }
    }

    private var dependencyStatusMenu: some View {
        Menu {
            Text("yt-dlp • \(checker.ytdlpStatus.title)")
            Text("FFmpeg • \(checker.ffmpegStatus.title)")
            Divider()
            Button("Re-check tools") {
                viewModel.recheckDeps()
            }
        } label: {
            HStack(spacing: MacYTSpacing.sm) {
                Circle()
                    .fill(overallStatusColor)
                    .frame(width: 9, height: 9)

                Text(overallStatusTitle)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(MacYTColors.textPrimary)

                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(MacYTColors.textSecondary)
            }
            .padding(.horizontal, MacYTSpacing.lg)
            .padding(.vertical, MacYTSpacing.md)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.05))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(overallStatusColor.opacity(0.35), lineWidth: 1)
            )
        }
        .menuStyle(.borderlessButton)
        .buttonStyle(.plain)
    }

    private var overallStatusTitle: String {
        if checker.allRequiredInstalled {
            return "All systems ready"
        }

        if checker.coreDependencyInstalled {
            return "1 tool needs attention"
        }

        return "Setup required"
    }

    private var overallStatusColor: Color {
        if checker.allRequiredInstalled {
            return MacYTColors.success
        }

        if checker.coreDependencyInstalled {
            return MacYTColors.warning
        }

        return MacYTColors.destructive
    }
}

#Preview {
    ContentView()
}
