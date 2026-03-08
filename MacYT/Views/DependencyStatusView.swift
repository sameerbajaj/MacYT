import SwiftUI

struct DependencyStatusView: View {
    @ObservedObject var viewModel: AppViewModel
    @ObservedObject var checker = DependencyChecker.shared
    
    var body: some View {
        VStack(spacing: MacYTSpacing.xl) {
            Spacer()
            
            Image(systemName: "gearshape.2.fill")
                .font(.system(size: 64))
                .foregroundColor(MacYTColors.accentGradientStart)
            
            Text("Checking Requirements")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: MacYTSpacing.lg) {
                StatusRow(name: "yt-dlp", status: checker.ytdlpStatus)
                StatusRow(name: "FFmpeg", status: checker.ffmpegStatus)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(MacYTCornerRadius.large)
            .shadow(color: Color.black.opacity(0.1), radius: 10, y: 5)
            .frame(maxWidth: 500)
            
            if !checker.ytdlpStatus.isInstalled || !checker.ffmpegStatus.isInstalled {
                VStack(spacing: MacYTSpacing.md) {
                    Text("You need `yt-dlp` and `ffmpeg` to use MacYT.")
                        .foregroundColor(MacYTColors.textSecondary)
                    
                    HStack {
                        Text("brew install yt-dlp ffmpeg")
                            .font(.system(.body, design: .monospaced))
                            .padding()
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(MacYTCornerRadius.medium)
                            .foregroundColor(.white)
                        
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString("brew install yt-dlp ffmpeg", forType: .string)
                        } label: {
                            Image(systemName: "doc.on.clipboard")
                        }
                        .buttonStyle(.plain)
                        .padding()
                        .background(MacYTColors.accentGradientStart)
                        .cornerRadius(MacYTCornerRadius.medium)
                        .foregroundColor(.white)
                    }
                    
                    Button("I've installed them, Re-check") {
                        viewModel.recheckDeps()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(MacYTColors.accentGradientStart)
                    .padding(.top, MacYTSpacing.md)
                }
            } else if viewModel.appState == .checkingDeps {
                ProgressView()
                    .padding(.top)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

private struct StatusRow: View {
    let name: String
    let status: DependencyStatus
    
    var body: some View {
        HStack {
            Text(name)
                .font(.headline)
                .frame(width: 80, alignment: .leading)
            
            Spacer()
            
            StatusBadge(status: status, name: name)
        }
        .padding(.vertical, 4)
    }
}
