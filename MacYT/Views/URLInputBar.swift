import SwiftUI

struct URLInputBar: View {
    @ObservedObject var viewModel: AppViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: MacYTSpacing.md) {
            MacYTSectionHeading(
                eyebrow: "Capture",
                title: "Drop in a link",
                subtitle: "Paste any supported video URL, inspect the available streams, then choose how you want the final file assembled."
            )

            HStack(spacing: MacYTSpacing.md) {
                HStack(spacing: MacYTSpacing.md) {
                    Image(systemName: "link.badge.plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(MacYTColors.accentGradientEnd)

                    TextField("Paste a YouTube URL, playlist, or short link…", text: $viewModel.urlText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(MacYTColors.textPrimary)
                        .onSubmit {
                            viewModel.fetchVideoInfo()
                        }
                        .disabled(viewModel.appState == .fetchingInfo || viewModel.appState == .downloading)

                    if !viewModel.urlText.isEmpty {
                        Button {
                            viewModel.urlText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(MacYTColors.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, MacYTSpacing.lg)
                .padding(.vertical, MacYTSpacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: MacYTCornerRadius.large, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: MacYTCornerRadius.large, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )

                Button {
                    viewModel.pasteURL()
                } label: {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(MacYTColors.textPrimary)
                        .frame(width: 52, height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: MacYTCornerRadius.large, style: .continuous)
                                .fill(Color.white.opacity(0.05))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: MacYTCornerRadius.large, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .help("Paste from Clipboard")

                GradientButton(
                    title: "Inspect",
                    icon: "sparkles.tv.fill",
                    isLoading: viewModel.appState == .fetchingInfo
                ) {
                    viewModel.fetchVideoInfo()
                }
                .frame(height: 52)
            }
        }
        .padding(MacYTSpacing.xl)
        .macYTCard()
    }
}
