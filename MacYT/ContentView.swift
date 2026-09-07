import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = AppViewModel()
    @ObservedObject private var checker = DependencyChecker.shared
    
    private var shouldShowDependencyScreen: Bool {
        if !checker.coreDependencyInstalled {
            if case .checkingError = viewModel.appState {
                return true
            }
            if case .checkingDeps = viewModel.appState, !viewModel.isInitialLaunch {
                return true
            }
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
    @State private var selectedSection: WorkspaceSection = .studio
    @State private var showDiagnosticsSheet = false
    
    var body: some View {
        HStack(alignment: .top, spacing: MacYTSpacing.xl) {
            WorkspaceSidebar(
                selectedSection: $selectedSection,
                viewModel: viewModel,
                checker: checker,
                onOpenDiagnostics: { showDiagnosticsSheet = true }
            )

            Group {
                switch selectedSection {
                case .studio:
                    studioWorkspace
                case .downloads:
                    downloadsWorkspace
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(.horizontal, MacYTSpacing.xl)
        .padding(.vertical, MacYTSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onChange(of: viewModel.downloadOptions.extractAudio) { _, _ in
            viewModel.refreshSelectionForCurrentMode()
        }
        .sheet(isPresented: $showDiagnosticsSheet) {
            DependencyStatusView(viewModel: viewModel) {
                showDiagnosticsSheet = false
            }
            .frame(minWidth: 720, minHeight: 520)
        }
    }

    private var studioWorkspace: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: MacYTSpacing.xl) {
                workspaceHero(
                    eyebrow: "Studio",
                    title: "Capture first. Export later.",
                    subtitle: "Keep the first screen focused on inspecting the link, seeing the artwork clearly, and choosing the right stream without the export controls crowding it."
                )

                infoChips

                notificationStack

                URLInputBar(viewModel: viewModel)

                VideoInfoCard(
                    info: viewModel.videoInfo,
                    isLoading: viewModel.appState == .fetchingInfo
                )

                if viewModel.showsFormatStage {
                    if viewModel.downloadOptions.extractAudio {
                        AudioExportSummaryView(
                            options: viewModel.downloadOptions,
                            formats: viewModel.formats,
                            duration: viewModel.videoInfo?.duration
                        )
                    } else {
                        FormatSelectionView(viewModel: viewModel)
                    }

                    SimpleAdvancedOptionsView(options: viewModel.downloadOptions)

                    if viewModel.downloadManager.status == .idle {
                        studioActionCard
                    }
                }

                if viewModel.downloadManager.status != .idle {
                    DownloadProgressView(
                        downloadManager: viewModel.downloadManager,
                        isAudioMode: viewModel.downloadOptions.extractAudio,
                        isDownloadActive: viewModel.isDownloadActive,
                        startDownload: viewModel.startDownload,
                        cancelDownload: viewModel.cancelDownload,
                        resetSession: viewModel.reset,
                        dismissStatus: viewModel.dismissDownloadStatus
                    )
                }
            }
            .padding(.bottom, MacYTSpacing.xl)
        }
    }

    private var downloadsWorkspace: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: MacYTSpacing.xl) {
                workspaceHero(
                    eyebrow: "Downloads",
                    title: "Exported files",
                    subtitle: "This tab shows files MacYT exported. Configure and start new exports in Studio."
                )

                ExportedFilesView(outputDirectory: viewModel.downloadOptions.outputDirectory) {
                    selectedSection = .studio
                }
            }
            .padding(.bottom, MacYTSpacing.xl)
        }
    }

    private var studioActionCard: some View {
        HStack(spacing: MacYTSpacing.lg) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Ready to export")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(MacYTColors.textPrimary)

                Text("Mode: \(viewModel.downloadOptions.extractAudio ? "Audio" : "Video") • Output: \(viewModel.downloadOptions.outputDirectory.lastPathComponent)")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(MacYTColors.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: MacYTSpacing.sm)

            GradientButton(
                title: "Download \(viewModel.downloadOptions.extractAudio ? "Audio" : "Video")",
                icon: "arrow.down.circle.fill",
                isLoading: viewModel.isDownloadActive
            ) {
                viewModel.startDownload()
            }
            .frame(height: 50)
        }
        .padding(MacYTSpacing.xl)
        .macYTCard()
    }

    private var infoChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: MacYTSpacing.sm) {
                MacYTInfoChip(
                    icon: viewModel.videoInfo == nil ? "film" : "film.stack.fill",
                    label: viewModel.videoInfo == nil ? "Awaiting link" : "Media loaded",
                    tint: MacYTColors.accentGradientEnd
                )
                MacYTInfoChip(
                    icon: viewModel.downloadOptions.extractAudio ? "music.note" : "play.rectangle.fill",
                    label: viewModel.downloadOptions.exportModeTitle
                )
                Button {
                    NSWorkspace.shared.open(viewModel.downloadOptions.outputDirectory)
                } label: {
                    MacYTInfoChip(icon: "folder.fill", label: viewModel.downloadOptions.outputDirectory.lastPathComponent)
                }
                .buttonStyle(.plain)
                .help("Open destination folder in Finder")

                if let info = viewModel.videoInfo {
                    MacYTInfoChip(icon: "clock.fill", label: info.durationString.isEmpty ? "Unknown length" : info.durationString)
                }
            }
        }
    }

    @ViewBuilder
    private var notificationStack: some View {
        if let warning = checker.ffmpegWarningText {
            MacYTInlineBanner(
                icon: checker.ffmpegStatus.isBroken ? "wrench.adjustable.fill" : "sparkles.tv.fill",
                title: checker.ffmpegStatus.isBroken ? "FFmpeg needs repair" : "FFmpeg not found",
                message: warning,
                tint: checker.ffmpegStatus.isBroken ? MacYTColors.warning : MacYTColors.accentGradientEnd
            )
        }

        if let err = viewModel.errorMessage {
            HStack(alignment: .top, spacing: MacYTSpacing.md) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(MacYTColors.destructive)
                    .frame(width: 28, height: 28)
                    .background(MacYTColors.destructive.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Action needed")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(MacYTColors.textPrimary)
                    Text(err)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(MacYTColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Button {
                    viewModel.errorMessage = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(MacYTColors.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: MacYTCornerRadius.large, style: .continuous)
                    .fill(Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: MacYTCornerRadius.large, style: .continuous)
                    .stroke(MacYTColors.destructive.opacity(0.22), lineWidth: 1)
            )
        }
    }

    private func workspaceHero(eyebrow: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: MacYTSpacing.lg) {
            VStack(alignment: .leading, spacing: 10) {
                Text(eyebrow.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(1.8)
                    .foregroundColor(MacYTColors.accentGradientEnd)

                Text(title)
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundColor(MacYTColors.textPrimary)

                Text(subtitle)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(MacYTColors.textSecondary)
                    .frame(maxWidth: 680, alignment: .leading)
            }

            Spacer(minLength: MacYTSpacing.lg)

            dependencyStatusMenu
        }
    }

    private var dependencyStatusMenu: some View {
        Menu {
            Text("yt-dlp • \(checker.ytdlpStatus.title)")
            Text("FFmpeg • \(checker.ffmpegStatus.title)")
            Divider()
            Button("Open Diagnostics…") {
                showDiagnosticsSheet = true
            }
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

private enum WorkspaceSection: String, CaseIterable, Identifiable {
    case studio
    case downloads

    var id: String { rawValue }

    var title: String {
        switch self {
        case .studio:
            return "Studio"
        case .downloads:
            return "Downloads"
        }
    }

    var subtitle: String {
        switch self {
        case .studio:
            return "Inspect links"
        case .downloads:
            return "Previously exported"
        }
    }

    var icon: String {
        switch self {
        case .studio:
            return "sparkles.tv.fill"
        case .downloads:
            return "square.stack.3d.up.fill"
        }
    }
}

private struct WorkspaceSidebar: View {
    @Binding var selectedSection: WorkspaceSection
    @ObservedObject var viewModel: AppViewModel
    @ObservedObject var checker: DependencyChecker
    var onOpenDiagnostics: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: MacYTSpacing.xl) {
            sidebarHeader
            sectionSwitcher

            Spacer(minLength: MacYTSpacing.md)

            statusPanel
        }
        .padding(MacYTSpacing.xl)
        .frame(width: 260)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .macYTCard()
    }

    private var sidebarHeader: some View {
        VStack(alignment: .leading, spacing: MacYTSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(sidebarBrandGradient)
                    .frame(width: 58, height: 58)

                Image(systemName: "play.tv.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
            }

            Text("MacYT")
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundColor(MacYTColors.textPrimary)

            Text("A two-room workflow for previewing first and exporting second.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(MacYTColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var sectionSwitcher: some View {
        VStack(spacing: MacYTSpacing.md) {
            ForEach(WorkspaceSection.allCases) { section in
                sectionButton(section)
            }
        }
    }

    private var statusPanel: some View {
        VStack(alignment: .leading, spacing: MacYTSpacing.md) {
            statusRow(icon: "film.stack.fill", title: viewModel.videoInfo == nil ? "No media yet" : "Media ready", tint: viewModel.videoInfo == nil ? MacYTColors.textTertiary : MacYTColors.success)
            Button {
                onOpenDiagnostics()
            } label: {
                statusRow(icon: checker.allRequiredInstalled ? "checkmark.seal.fill" : "exclamationmark.triangle.fill", title: checker.allRequiredInstalled ? "Tools healthy" : "Tool attention", tint: checker.allRequiredInstalled ? MacYTColors.success : MacYTColors.warning)
            }
            .buttonStyle(.plain)
            .help("Open Diagnostics")

            Button {
                NSWorkspace.shared.open(viewModel.downloadOptions.outputDirectory)
            } label: {
                statusRow(icon: "folder.fill", title: viewModel.downloadOptions.outputDirectory.lastPathComponent, tint: MacYTColors.accentGradientEnd)
            }
            .buttonStyle(.plain)
            .help("Open destination folder in Finder")
        }
        .padding(MacYTSpacing.lg)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: MacYTCornerRadius.xLarge, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: MacYTCornerRadius.xLarge, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private var sidebarBrandGradient: LinearGradient {
        LinearGradient(
            colors: [MacYTColors.accentGradientStart.opacity(0.95), MacYTColors.accentGradientEnd.opacity(0.95)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func sectionButton(_ section: WorkspaceSection) -> some View {
        let isSelected = section == selectedSection

        return Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                selectedSection = section
            }
        } label: {
            HStack(spacing: MacYTSpacing.md) {
                Image(systemName: section.icon)
                    .font(.system(size: 15, weight: .bold))
                    .frame(width: 34, height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(isSelected ? Color.white.opacity(0.16) : Color.white.opacity(0.05))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(section.title)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                    Text(section.subtitle)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(MacYTColors.textSecondary)
                }

                Spacer(minLength: 0)
            }
            .foregroundColor(MacYTColors.textPrimary)
            .padding(MacYTSpacing.md)
            .background(sectionBackground(isSelected: isSelected))
            .overlay(sectionBorder(isSelected: isSelected))
        }
        .buttonStyle(.plain)
    }

    private func sectionBackground(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: MacYTCornerRadius.large, style: .continuous)
            .fill(isSelected ? MacYTColors.accentGlow.opacity(0.22) : Color.white.opacity(0.04))
    }

    private func sectionBorder(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: MacYTCornerRadius.large, style: .continuous)
            .stroke(isSelected ? MacYTColors.accentGradientEnd.opacity(0.48) : Color.white.opacity(0.06), lineWidth: 1)
    }

    private func statusRow(icon: String, title: String, tint: Color) -> some View {
        HStack(spacing: MacYTSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(tint)
                .frame(width: 30, height: 30)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(MacYTColors.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 0)
        }
    }
}

#Preview {
    ContentView()
}
