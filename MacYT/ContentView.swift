import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = AppViewModel()
    
    var body: some View {
        Group {
            if viewModel.appState == .checkingDeps || viewModel.appState == .checkingError("") {
                DependencyStatusView(viewModel: viewModel)
            } else {
                MainAppView(viewModel: viewModel)
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct MainAppView: View {
    @ObservedObject var viewModel: AppViewModel
    
    var body: some View {
        HStack(spacing: 0) {
            // Main Content Area
            VStack(spacing: MacYTSpacing.lg) {
                URLInputBar(viewModel: viewModel)
                    .padding(.top, MacYTSpacing.xl)
                
                if let err = viewModel.errorMessage {
                    Text(err)
                        .foregroundColor(MacYTColors.destructive)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(MacYTColors.destructive.opacity(0.1))
                        .cornerRadius(MacYTCornerRadius.medium)
                        .padding(.horizontal)
                }
                
                ScrollView {
                    VStack(spacing: MacYTSpacing.xl) {
                        VideoInfoCard(
                            info: viewModel.videoInfo,
                            isLoading: viewModel.appState == .fetchingInfo
                        )
                        
                        if viewModel.appState == .showingFormats || viewModel.appState == .downloading || viewModel.appState == .completed {
                            FormatSelectionView(viewModel: viewModel)
                        }
                    }
                    .padding(.bottom, 120) // space for progress bar
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Sidebar
            DownloadOptionsPanel(options: viewModel.downloadOptions)
        }
        // Floating Progress Area
        .overlay(
            VStack {
                Spacer()
                if viewModel.appState == .showingFormats || viewModel.appState == .downloading || viewModel.appState == .completed {
                    DownloadProgressView(viewModel: viewModel)
                        .padding()
                        .background(
                            Rectangle()
                                .fill(Color(NSColor.windowBackgroundColor).opacity(0.95))
                                .shadow(color: Color.black.opacity(0.1), radius: 10, y: -5)
                        )
                }
            },
            alignment: .bottom
        )
    }
}

#Preview {
    ContentView()
}
