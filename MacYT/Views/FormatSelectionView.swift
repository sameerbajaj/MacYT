import SwiftUI

struct FormatSelectionView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var filterMode: Int = 0 // 0: All, 1: Video Only, 2: Audio Only
    
    var body: some View {
        VStack(alignment: .leading, spacing: MacYTSpacing.md) {
            HStack {
                Text("Select Format")
                    .font(.headline)
                    .foregroundColor(MacYTColors.textPrimary)
                
                Spacer()
                
                Picker("", selection: $filterMode) {
                    Text("Standard").tag(0)
                    Text("Video Only").tag(1)
                    Text("Audio Only").tag(2)
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 250)
            }
            .padding(.horizontal)
            
            if viewModel.formats.isEmpty {
                Text("No formats available")
                    .foregroundColor(MacYTColors.textSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(MacYTCornerRadius.medium)
                    .padding()
            } else {
                let filtered = viewModel.formats.filter { f in
                    if filterMode == 1 { return f.isVideoOnly }
                    if filterMode == 2 { return f.isAudioOnly }
                    return !f.isVideoOnly && !f.isAudioOnly
                }
                
                List(filtered, selection: $viewModel.selectedFormatId) { format in
                    HStack {
                        Text(format.displayResolution)
                            .frame(width: 100, alignment: .leading)
                            .fontWeight(.medium)
                        
                        Text(format.displayCodec)
                            .frame(width: 120, alignment: .leading)
                            .foregroundColor(MacYTColors.textSecondary)
                        
                        Spacer()
                        
                        Text(format.humanFileSize)
                            .frame(width: 100, alignment: .trailing)
                            .foregroundColor(MacYTColors.textSecondary)
                        
                        Text(format.ext)
                            .frame(width: 60, alignment: .trailing)
                            .foregroundColor(MacYTColors.textSecondary)
                    }
                    .padding(.vertical, 4)
                    .tag(format.formatId)
                }
                .listStyle(PlainListStyle())
                .cornerRadius(MacYTCornerRadius.medium)
                .overlay(
                    RoundedRectangle(cornerRadius: MacYTCornerRadius.medium)
                        .stroke(MacYTColors.separator, lineWidth: 0.5)
                )
                .padding(.horizontal)
            }
        }
    }
}
