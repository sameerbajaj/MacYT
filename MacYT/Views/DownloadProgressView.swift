import SwiftUI

struct DownloadProgressView: View {
    @ObservedObject var downloadManager: DownloadManager
    let isAudioMode: Bool
    let isDownloadActive: Bool
    let startDownload: () -> Void
    let cancelDownload: () -> Void
    let resetSession: () -> Void
    var dismissStatus: (() -> Void)? = nil
    
    @State private var showConsoleLogs = false

    var body: some View {
        VStack(spacing: MacYTSpacing.md) {
            switch downloadManager.status {
            case .idle:
                HStack {
                    Text("Ready to export")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(MacYTColors.textSecondary)
                    Spacer()
                    GradientButton(
                        title: "Download \(isAudioMode ? "Audio" : "Video")",
                        icon: "arrow.down.circle.fill",
                        isLoading: false
                    ) {
                        startDownload()
                    }
                    .frame(height: 50)
                }
                
            case .cancelled:
                VStack(alignment: .leading, spacing: MacYTSpacing.md) {
                    HStack(alignment: .center) {
                        Image(systemName: "slash.circle")
                            .foregroundColor(MacYTColors.warning)
                            .font(.title2)

                        Text("Download cancelled")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(MacYTColors.textPrimary)

                        Spacer()

                        if let dismissStatus {
                            Button("Dismiss") {
                                dismissStatus()
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(MacYTColors.textTertiary)
                            .padding(.horizontal, MacYTSpacing.sm)
                        }
                    }

                    Text("The export was stopped before completion.")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(MacYTColors.textSecondary)

                    GradientButton(title: "Restart", icon: "arrow.clockwise", isLoading: false) {
                        startDownload()
                    }
                    .frame(height: 40)
                }
                .padding()
                .background(MacYTColors.warning.opacity(0.1))
                .cornerRadius(MacYTCornerRadius.large)

            case .fetching:
                ProgressRow(title: "Starting download…", progress: nil, speed: "", eta: "")
                
            case .downloading(let percent, let speed, let eta):
                ProgressRow(title: "Downloading…", progress: percent, speed: speed, eta: eta)
                
            case .postProcessing:
                ProgressRow(title: "Processing (Merging / Converting)…", progress: nil, speed: "", eta: "")
                
            case .completed(let path):
                VStack(alignment: .leading, spacing: MacYTSpacing.md) {
                    HStack(alignment: .center) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(MacYTColors.success)
                            .font(.title2)

                        Text("Download completed")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(MacYTColors.textPrimary)

                        Spacer()

                        if let dismissStatus {
                            Button("Dismiss") {
                                dismissStatus()
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(MacYTColors.textTertiary)
                            .padding(.horizontal, MacYTSpacing.sm)
                        }
                    }

                    Text(path)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(MacYTColors.textTertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: MacYTSpacing.md) {
                        Button {
                            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "folder")
                                Text("Reveal in Finder")
                            }
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(MacYTColors.accentGradientEnd)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(MacYTColors.accentGradientEnd.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)

                        Button {
                            resetSession()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus.circle")
                                Text("New Download")
                            }
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(MacYTColors.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)

                        Spacer()
                    }
                }
                .padding()
                .background(MacYTColors.success.opacity(0.12))
                .cornerRadius(MacYTCornerRadius.large)
                
            case .failed(let error):
                VStack(alignment: .leading, spacing: MacYTSpacing.md) {
                    HStack(alignment: .center) {
                        Image(systemName: "xmark.octagon.fill")
                            .foregroundColor(MacYTColors.destructive)
                            .font(.title2)

                        Text("Download Failed")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(MacYTColors.textPrimary)

                        Spacer()

                        if let dismissStatus {
                            Button("Dismiss") {
                                dismissStatus()
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(MacYTColors.textTertiary)
                            .padding(.horizontal, MacYTSpacing.sm)
                        }
                    }

                    Text(error)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(MacYTColors.destructive.opacity(0.92))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)

                    GradientButton(title: "Retry", icon: "arrow.clockwise", isLoading: false) {
                        startDownload()
                    }
                    .frame(height: 40)
                }
                .padding()
                .background(MacYTColors.destructive.opacity(0.1))
                .cornerRadius(MacYTCornerRadius.large)
            }
            
            if isDownloadActive {
                HStack {
                    Spacer()
                    Button("Cancel") {
                        cancelDownload()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            if !downloadManager.consoleLogs.isEmpty {
                DisclosureGroup(isExpanded: $showConsoleLogs) {
                    ScrollView(showsIndicators: true) {
                        LazyVStack(alignment: .leading, spacing: 3) {
                            ForEach(Array(downloadManager.consoleLogs.suffix(20).enumerated()), id: \.offset) { _, line in
                                Text(line)
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundColor(MacYTColors.textTertiary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(MacYTSpacing.sm)
                    }
                    .frame(maxHeight: 140)
                    .background(Color.black.opacity(0.3), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                } label: {
                    Text(showConsoleLogs ? "Hide Terminal Output" : "View Terminal Output (\(downloadManager.consoleLogs.count) lines)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(MacYTColors.textSecondary)
                }
            }
        }
        .padding(MacYTSpacing.lg)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: MacYTCornerRadius.xLarge, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: MacYTCornerRadius.xLarge, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.28), radius: 18, y: 12)
    }
}

private struct ProgressRow: View {
    let title: String
    let progress: Double?
    let speed: String
    let eta: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: MacYTSpacing.sm) {
            HStack {
                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(MacYTColors.textPrimary)
                Spacer()
                if let p = progress {
                    Text("\(Int(p * 100))%")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(MacYTColors.accentGradientStart)
                }
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 12)
                    
                    if let p = progress {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [MacYTColors.accentGradientStart, MacYTColors.accentGradientEnd],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(0, geo.size.width * p), height: 12)
                            .animation(.linear(duration: 0.2), value: p)
                    } else {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [MacYTColors.accentGradientStart, MacYTColors.accentGradientEnd],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width, height: 12)
                            .shimmerEffect()
                    }
                }
            }
            .frame(height: 12)
            
            HStack {
                if !speed.isEmpty {
                    Text("Speed: \(speed)")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(MacYTColors.textSecondary)
                }
                Spacer()
                if !eta.isEmpty {
                    Text("ETA: \(eta)")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(MacYTColors.textSecondary)
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.04))
        .cornerRadius(MacYTCornerRadius.large)
        .overlay(
            RoundedRectangle(cornerRadius: MacYTCornerRadius.large)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}
