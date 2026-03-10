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
    @State private var selectedSection: WorkspaceSection = .studio
    
    var body: some View {
        GeometryReader { _ in
            HStack(alignment: .top, spacing: MacYTSpacing.xl) {
                WorkspaceSidebar(
                    selectedSection: $selectedSection,
                    viewModel: viewModel,
                    checker: checker
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
            .padding(.horizontal, MacYTSpacing.xxl)
            .padding(.vertical, MacYTSpacing.xl)
        }
        .onChange(of: viewModel.downloadOptions.extractAudio) { _, _ in
            viewModel.refreshSelectionForCurrentMode()
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
                    studioActionCard
                }

                if viewModel.isDownloadActive || viewModel.appState == .completed {
                    DownloadProgressView(viewModel: viewModel)
                }
            }
            .padding(.bottom, 116)
        }
        .mask(
            LinearGradient(
                colors: [.clear, .black, .black, .clear],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var downloadsWorkspace: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: MacYTSpacing.xl) {
                workspaceHero(
                    eyebrow: "Downloads",
                    title: "Exported files",
                    subtitle: "This tab only shows what is already downloaded. Configure and start new exports in Studio."
                )

                ExportedFilesView(directory: viewModel.downloadOptions.outputDirectory)
            }
            .padding(.bottom, 116)
        }
        .mask(
            LinearGradient(
                colors: [.clear, .black, .black, .clear],
                startPoint: .top,
                endPoint: .bottom
            )
        )
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
            }

            Spacer(minLength: 0)

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
                MacYTInfoChip(icon: "folder.fill", label: viewModel.downloadOptions.outputDirectory.lastPathComponent)
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
            MacYTInlineBanner(
                icon: "exclamationmark.triangle.fill",
                title: "Action needed",
                message: err,
                tint: MacYTColors.destructive
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

    private var studioNextStepCard: some View {
        HStack(alignment: .center, spacing: MacYTSpacing.lg) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Next step")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(1.6)
                    .foregroundColor(MacYTColors.accentGradientEnd)

                Text("When the preview looks right, finish the job in Downloads.")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(MacYTColors.textPrimary)

                Text("That tab now holds the export controls, live activity, and session log so this studio stays focused on inspection and quality selection.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(MacYTColors.textSecondary)
                    .frame(maxWidth: 520, alignment: .leading)
            }

            Spacer(minLength: MacYTSpacing.lg)

            GradientButton(title: "Open Downloads", icon: "square.stack.3d.up.fill", isLoading: false) {
                selectedSection = .downloads
            }
            .frame(height: 50)
        }
        .padding(MacYTSpacing.xl)
        .macYTCard()
    }

    private var downloadsEmptyState: some View {
        VStack(alignment: .leading, spacing: MacYTSpacing.lg) {
            Image(systemName: "tray.and.arrow.down.fill")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(MacYTColors.accentGradientEnd)

            Text("Nothing is queued yet")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(MacYTColors.textPrimary)

            Text("Inspect a link in Studio first. Once the media loads, this desk becomes the dedicated place for export settings, download progress, and raw session output.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(MacYTColors.textSecondary)
                .frame(maxWidth: 520, alignment: .leading)

            GradientButton(title: "Go to Studio", icon: "sparkles.tv.fill", isLoading: false) {
                selectedSection = .studio
            }
            .frame(height: 50)
        }
        .padding(MacYTSpacing.xxxl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .macYTCard()
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

    var body: some View {
        VStack(alignment: .leading, spacing: MacYTSpacing.xl) {
            sidebarHeader
            sectionSwitcher
            statusPanel

            Spacer(minLength: 0)
        }
        .padding(MacYTSpacing.xl)
        .frame(width: 300)
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
            statusRow(icon: checker.allRequiredInstalled ? "checkmark.seal.fill" : "exclamationmark.triangle.fill", title: checker.allRequiredInstalled ? "Tools healthy" : "Tool attention", tint: checker.allRequiredInstalled ? MacYTColors.success : MacYTColors.warning)
            statusRow(icon: "folder.fill", title: viewModel.downloadOptions.outputDirectory.lastPathComponent, tint: MacYTColors.accentGradientEnd)
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

private struct DownloadDeskCard: View {
    @ObservedObject var viewModel: AppViewModel
    @Binding var selectedSection: WorkspaceSection

    var body: some View {
        VStack(alignment: .leading, spacing: MacYTSpacing.xl) {
            HStack(alignment: .top) {
                MacYTSectionHeading(
                    eyebrow: "Activity",
                    title: statusTitle,
                    subtitle: statusSubtitle
                )

                Spacer(minLength: MacYTSpacing.lg)

                statusBadge
            }

            VStack(alignment: .leading, spacing: MacYTSpacing.md) {
                metadataRow(title: "Source", value: viewModel.videoInfo?.title ?? "No media loaded")
                metadataRow(title: "Mode", value: viewModel.downloadOptions.exportModeTitle)
                metadataRow(title: "Selection", value: viewModel.exportSelectionSummary)
                metadataRow(title: "Destination", value: viewModel.downloadOptions.outputDirectory.path)
            }

            if let progress = activeProgress {
                VStack(alignment: .leading, spacing: MacYTSpacing.sm) {
                    HStack {
                        Text("Current progress")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(MacYTColors.textSecondary)

                        Spacer()

                        Text(progress.label)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(MacYTColors.textPrimary)
                    }

                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule(style: .continuous)
                                .fill(Color.white.opacity(0.08))
                                .frame(height: 12)

                            Capsule(style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [MacYTColors.accentGradientStart, MacYTColors.accentGradientEnd],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(16, proxy.size.width * progress.value), height: 12)
                                .animation(.linear(duration: 0.2), value: progress.value)
                        }
                    }
                    .frame(height: 12)
                }
            }

            HStack(spacing: MacYTSpacing.md) {
                primaryActionButton

                if viewModel.isDownloadActive {
                    Button("Cancel") {
                        viewModel.cancelDownload()
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(MacYTColors.destructive)
                    .padding(.horizontal, MacYTSpacing.lg)
                    .padding(.vertical, MacYTSpacing.md)
                    .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: MacYTCornerRadius.large, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: MacYTCornerRadius.large, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                }
            }
        }
        .padding(MacYTSpacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .macYTCard()
    }

    private var statusBadge: some View {
        Label(statusChipTitle, systemImage: statusIcon)
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundColor(statusTint)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(statusTint.opacity(0.14), in: Capsule(style: .continuous))
    }

    @ViewBuilder
    private var primaryActionButton: some View {
        switch viewModel.downloadManager.status {
        case .completed:
            GradientButton(title: "Reveal in Finder", icon: "folder.fill", isLoading: false) {
                selectedSection = .downloads
                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: viewModel.downloadOptions.outputDirectory.path)
            }
            .frame(height: 50)

        case .failed:
            GradientButton(title: "Retry Download", icon: "arrow.clockwise", isLoading: false) {
                viewModel.startDownload()
            }
            .frame(height: 50)

        case .fetching, .downloading, .postProcessing:
            GradientButton(title: "Working…", icon: "arrow.down.circle.fill", isLoading: true) {}
                .frame(height: 50)

        case .idle, .cancelled:
            GradientButton(title: "Download \(viewModel.downloadOptions.extractAudio ? "Audio" : "Video")", icon: "arrow.down.circle.fill", isLoading: false) {
                viewModel.startDownload()
            }
            .frame(height: 50)
        }
    }

    private func metadataRow(title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: MacYTSpacing.md) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(1.3)
                .foregroundColor(MacYTColors.textTertiary)
                .frame(width: 88, alignment: .leading)

            Text(value)
                .font(.system(size: 13, weight: .semibold, design: title == "Destination" ? .monospaced : .rounded))
                .foregroundColor(MacYTColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(MacYTSpacing.md)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: MacYTCornerRadius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: MacYTCornerRadius.large, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private var statusTitle: String {
        switch viewModel.downloadManager.status {
        case .idle, .cancelled:
            return "Ready to export"
        case .fetching:
            return "Preparing the download"
        case .downloading:
            return "Download in progress"
        case .postProcessing:
            return "Finishing the file"
        case .completed:
            return "Download completed"
        case .failed:
            return "Download hit an issue"
        }
    }

    private var statusSubtitle: String {
        switch viewModel.downloadManager.status {
        case .idle, .cancelled:
            return "The floating dock stays quiet now. Kick off the export here when you are ready."
        case .fetching:
            return "MacYT is asking yt-dlp for the file and preparing the destination path."
        case let .downloading(_, speed, eta):
            return "Speed \(speed.isEmpty ? "unknown" : speed) • ETA \(eta.isEmpty ? "calculating" : eta)"
        case .postProcessing:
            return "yt-dlp is merging tracks or converting the finished asset."
        case .completed:
            return "The file is finished. Reveal it in Finder or start a fresh session."
        case let .failed(error):
            return error
        }
    }

    private var statusIcon: String {
        switch viewModel.downloadManager.status {
        case .idle, .cancelled:
            return "checkmark.circle.fill"
        case .fetching:
            return "arrow.trianglehead.2.clockwise.rotate.90"
        case .downloading:
            return "arrow.down.circle.fill"
        case .postProcessing:
            return "wand.and.stars"
        case .completed:
            return "checkmark.seal.fill"
        case .failed:
            return "xmark.octagon.fill"
        }
    }

    private var statusChipTitle: String {
        switch viewModel.downloadManager.status {
        case .idle, .cancelled:
            return "Standing by"
        case .fetching:
            return "Starting"
        case .downloading:
            return "Downloading"
        case .postProcessing:
            return "Processing"
        case .completed:
            return "Done"
        case .failed:
            return "Needs retry"
        }
    }

    private var statusTint: Color {
        switch viewModel.downloadManager.status {
        case .idle, .cancelled:
            return MacYTColors.accentGradientEnd
        case .fetching, .downloading, .postProcessing:
            return MacYTColors.accentGradientStart
        case .completed:
            return MacYTColors.success
        case .failed:
            return MacYTColors.destructive
        }
    }

    private var activeProgress: (value: Double, label: String)? {
        switch viewModel.downloadManager.status {
        case let .downloading(percent, _, _):
            return (percent, "\(Int(percent * 100))%")
        default:
            return nil
        }
    }
}

private struct DownloadConsoleCard: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: MacYTSpacing.lg) {
            HStack {
                MacYTSectionHeading(
                    eyebrow: "Session log",
                    title: "Recent terminal output",
                    subtitle: "Keep the noisy bits here instead of stretched across the whole app."
                )

                Spacer(minLength: MacYTSpacing.lg)

                Text("\(viewModel.downloadManager.consoleLogs.count) lines")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(MacYTColors.textTertiary)
            }

            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: MacYTSpacing.sm) {
                    if viewModel.downloadManager.consoleLogs.isEmpty {
                        Text("No session output yet. Start a download to see yt-dlp activity here.")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(MacYTColors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(MacYTSpacing.lg)
                    } else {
                        ForEach(Array(viewModel.downloadManager.consoleLogs.suffix(18).enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundColor(MacYTColors.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, MacYTSpacing.md)
                                .padding(.vertical, 10)
                                .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                }
            }
            .frame(minHeight: 220, maxHeight: 300)
        }
        .padding(MacYTSpacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .macYTCard()
    }
}

private struct FloatingDownloadDock: View {
    @ObservedObject var viewModel: AppViewModel
    @Binding var selectedSection: WorkspaceSection

    var body: some View {
        HStack(spacing: MacYTSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(tint)
                .frame(width: 38, height: 38)
                .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(MacYTColors.textPrimary)
                Text(detail)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(MacYTColors.textSecondary)
                    .lineLimit(1)
            }

            if let progressLabel {
                Text(progressLabel)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(MacYTColors.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.08), in: Capsule(style: .continuous))
            }

            Button(action: primaryAction) {
                Image(systemName: actionIcon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 42, height: 42)
                    .background(
                        LinearGradient(
                            colors: [MacYTColors.accentGradientStart, MacYTColors.accentGradientEnd],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, MacYTSpacing.md)
        .padding(.trailing, 8)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule(style: .continuous))
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.28), radius: 18, y: 12)
        .onTapGesture {
            selectedSection = .downloads
        }
    }

    private var icon: String {
        switch viewModel.downloadManager.status {
        case .idle, .cancelled:
            return "checkmark.circle.fill"
        case .fetching:
            return "arrow.trianglehead.2.clockwise.rotate.90"
        case .downloading:
            return "arrow.down.circle.fill"
        case .postProcessing:
            return "wand.and.stars"
        case .completed:
            return "checkmark.seal.fill"
        case .failed:
            return "xmark.octagon.fill"
        }
    }

    private var tint: Color {
        switch viewModel.downloadManager.status {
        case .idle, .cancelled:
            return MacYTColors.accentGradientEnd
        case .fetching, .downloading, .postProcessing:
            return MacYTColors.accentGradientStart
        case .completed:
            return MacYTColors.success
        case .failed:
            return MacYTColors.destructive
        }
    }

    private var title: String {
        switch viewModel.downloadManager.status {
        case .idle, .cancelled:
            return "Ready"
        case .fetching:
            return "Preparing"
        case .downloading:
            return "Downloading"
        case .postProcessing:
            return "Processing"
        case .completed:
            return "Completed"
        case .failed:
            return "Retry needed"
        }
    }

    private var detail: String {
        switch viewModel.downloadManager.status {
        case .idle, .cancelled:
            return viewModel.exportSelectionSummary
        case let .downloading(_, speed, eta):
            return "\(speed.isEmpty ? "Working" : speed) • ETA \(eta.isEmpty ? "--" : eta)"
        case .completed:
            return "Reveal the file or start another export"
        case let .failed(error):
            return error
        case .fetching:
            return "Talking to yt-dlp"
        case .postProcessing:
            return "Finishing the file"
        }
    }

    private var progressLabel: String? {
        if case let .downloading(percent, _, _) = viewModel.downloadManager.status {
            return "\(Int(percent * 100))%"
        }
        return nil
    }

    private var actionIcon: String {
        switch viewModel.downloadManager.status {
        case .idle, .cancelled:
            return "arrow.down"
        case .completed:
            return "folder"
        case .failed:
            return "arrow.clockwise"
        default:
            return "slider.horizontal.3"
        }
    }

    private func primaryAction() {
        switch viewModel.downloadManager.status {
        case .idle, .cancelled:
            if selectedSection == .downloads {
                viewModel.startDownload()
            } else {
                selectedSection = .downloads
            }
        case .completed:
            selectedSection = .downloads
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: viewModel.downloadOptions.outputDirectory.path)
        case .failed:
            viewModel.startDownload()
        case .fetching, .downloading, .postProcessing:
            selectedSection = .downloads
        }
    }
}

private extension AppViewModel {
    var showsFormatStage: Bool {
        switch appState {
        case .showingFormats, .downloading, .completed:
            return true
        default:
            return false
        }
    }

    var shouldShowFloatingDock: Bool {
        showsFormatStage || isDownloadActive
    }

    var isDownloadActive: Bool {
        switch downloadManager.status {
        case .fetching, .downloading, .postProcessing:
            return true
        default:
            return false
        }
    }

    var exportSelectionSummary: String {
        if downloadOptions.extractAudio {
            return "\(downloadOptions.audioFormat.uppercased()) • \(downloadOptions.audioBitrate.label)"
        }

        if let selectedFormatId,
           let format = formats.first(where: { $0.formatId == selectedFormatId }) {
            return "\(format.displayResolution) • \(format.ext.uppercased())"
        }

        if let fallback = formats.first(where: { !$0.isAudioOnly }) {
            return "\(fallback.displayResolution) • \(fallback.ext.uppercased())"
        }

        return "Auto selection"
    }
}

#Preview {
    ContentView()
}
