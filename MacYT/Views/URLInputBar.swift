import SwiftUI

struct URLInputBar: View {
    @ObservedObject var viewModel: AppViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: MacYTSpacing.lg) {
            VStack(alignment: .leading, spacing: 6) {
                Text("CAPTURE")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(1.6)
                    .foregroundColor(MacYTColors.accentGradientEnd)

                HStack(alignment: .center, spacing: MacYTSpacing.lg) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Inspect a link")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(MacYTColors.textPrimary)

                        Text("Paste a URL, preview the media, then head to Downloads only when the source looks right.")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(MacYTColors.textSecondary)
                    }

                    Spacer(minLength: MacYTSpacing.md)

                    if !viewModel.urlText.isEmpty {
                        MacYTInfoChip(icon: "link", label: "Link staged", tint: MacYTColors.accentGradientEnd)
                    }
                }
            }

            HStack(spacing: MacYTSpacing.sm) {
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
                .frame(height: 52)
                .padding(.horizontal, MacYTSpacing.lg)
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
        .padding(.horizontal, MacYTSpacing.xl)
        .padding(.vertical, 22)
        .macYTCard()
    }
}
