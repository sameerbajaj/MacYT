import SwiftUI

struct URLInputBar: View {
    @ObservedObject var viewModel: AppViewModel
    
    var body: some View {
        HStack(spacing: MacYTSpacing.md) {
            HStack {
                Image(systemName: "link")
                    .foregroundColor(MacYTColors.textSecondary)
                
                TextField("Paste YouTube URL here...", text: $viewModel.urlText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(.body, design: .monospaced))
                    .onSubmit {
                        viewModel.fetchVideoInfo()
                    }
                    .disabled(viewModel.appState == .fetchingInfo || viewModel.appState == .downloading)
                
                if !viewModel.urlText.isEmpty {
                    Button {
                        viewModel.urlText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, MacYTSpacing.md)
            .padding(.vertical, MacYTSpacing.md)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(MacYTCornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: MacYTCornerRadius.medium)
                    .stroke(MacYTColors.separator, lineWidth: 0.5)
            )
            
            Button {
                viewModel.pasteURL()
            } label: {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(MacYTColors.textSecondary)
                    .frame(width: 44, height: 44)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(MacYTCornerRadius.medium)
                    .overlay(
                        RoundedRectangle(cornerRadius: MacYTCornerRadius.medium)
                            .stroke(MacYTColors.separator, lineWidth: 0.5)
                    )
            }
            .buttonStyle(PlainButtonStyle())
            .help("Paste from Clipboard")
            
            GradientButton(
                title: "Fetch",
                icon: "arrow.down.circle.fill",
                isLoading: viewModel.appState == .fetchingInfo
            ) {
                viewModel.fetchVideoInfo()
            }
            .frame(height: 44)
        }
        .padding(.horizontal)
    }
}
