import SwiftUI

struct DownloadProgressView: View {
    @ObservedObject var viewModel: AppViewModel
    
    var body: some View {
        VStack(spacing: MacYTSpacing.md) {
            switch viewModel.downloadManager.status {
            case .idle, .cancelled:
                HStack {
                    Spacer()
                    GradientButton(
                        title: "Download \(viewModel.downloadOptions.extractAudio ? "Audio" : "Video")",
                        icon: "arrow.down.circle.fill",
                        isLoading: false
                    ) {
                        viewModel.startDownload()
                    }
                    .frame(height: 44)
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
                    Text("Download Completed")
                        .font(.headline)
                    Spacer()
                    Button("Reveal in Finder") {
                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: viewModel.downloadOptions.outputDirectory.path)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(MacYTColors.accentGradientStart)
                    
                    Button("New Download") {
                        viewModel.reset()
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, MacYTSpacing.md)
                }
                .padding()
                .background(MacYTColors.success.opacity(0.1))
                .cornerRadius(MacYTCornerRadius.large)
                
            case .failed(let error):
                HStack {
                    Image(systemName: "xmark.octagon.fill")
                        .foregroundColor(MacYTColors.destructive)
                        .font(.title2)
                    VStack(alignment: .leading) {
                        Text("Download Failed")
                            .font(.headline)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(MacYTColors.destructive)
                            .lineLimit(2)
                    }
                    Spacer()
                    Button("Retry") {
                        viewModel.startDownload()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(MacYTColors.accentGradientStart)
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
                    .font(.headline)
                Spacer()
                if let p = progress {
                    Text("\(Int(p * 100))%")
                        .font(.headline)
                        .foregroundColor(MacYTColors.accentGradientStart)
                }
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(NSColor.windowBackgroundColor))
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
                        .font(.caption)
                        .foregroundColor(MacYTColors.textSecondary)
                }
                Spacer()
                if !eta.isEmpty {
                    Text("ETA: \(eta)")
                        .font(.caption)
                        .foregroundColor(MacYTColors.textSecondary)
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(MacYTCornerRadius.large)
        .overlay(
            RoundedRectangle(cornerRadius: MacYTCornerRadius.large)
                .stroke(MacYTColors.separator, lineWidth: 0.5)
        )
    }
}
