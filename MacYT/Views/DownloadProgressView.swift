import SwiftUI

struct DownloadProgressView: View {
    @ObservedObject var viewModel: AppViewModel
    
    var body: some View {
        VStack(spacing: MacYTSpacing.md) {
            switch viewModel.downloadManager.status {
            case .idle, .cancelled:
                HStack {
                    Text("Ready to export")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(MacYTColors.textSecondary)
                    Spacer()
                    GradientButton(
                        title: "Download \(viewModel.downloadOptions.extractAudio ? "Audio" : "Video")",
                        icon: "arrow.down.circle.fill",
                        isLoading: false
                    ) {
                        viewModel.startDownload()
                    }
                    .frame(height: 50)
                }
                
            case .fetching:
                ProgressRow(title: "Starting download...", progress: nil, speed: "", eta: "")
                
            case .downloading(let percent, let speed, let eta):
                ProgressRow(title: "Downloading...", progress: percent, speed: speed, eta: eta)
                
            case .postProcessing:
                ProgressRow(title: "Processing (Merging / Extracting Audio)...", progress: nil, speed: "", eta: "")
                
            case .completed(let path):
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(MacYTColors.success)
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Download completed")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(MacYTColors.textPrimary)
                        Text(path)
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundColor(MacYTColors.textTertiary)
                    }
                    Spacer()
                    Button("Reveal in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(MacYTColors.accentGradientEnd)
                    
                    Button("New Download") {
                        viewModel.reset()
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, MacYTSpacing.md)
                }
                .padding()
                .background(MacYTColors.success.opacity(0.12))
                .cornerRadius(MacYTCornerRadius.large)
                
            case .failed(let error):
                HStack {
                    Image(systemName: "xmark.octagon.fill")
                        .foregroundColor(MacYTColors.destructive)
                        .font(.title2)
                    VStack(alignment: .leading) {
                        Text("Download Failed")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(MacYTColors.textPrimary)
                        Text(error)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(MacYTColors.destructive.opacity(0.92))
                            .lineLimit(2)
                    }
                    Spacer()
                    GradientButton(title: "Retry", icon: "arrow.clockwise", isLoading: false) {
                        viewModel.startDownload()
                    }
                    .frame(height: 46)
                }
                .padding()
                .background(MacYTColors.destructive.opacity(0.1))
                .cornerRadius(MacYTCornerRadius.large)
            }
            
            if viewModel.appState == .downloading {
                HStack {
                    Spacer()
                    Button("Cancel") {
                        viewModel.cancelDownload()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
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
