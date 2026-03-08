import SwiftUI

struct AudioExtractionView: View {
    @ObservedObject var options: DownloadOptions
    
    var body: some View {
        VStack(spacing: 0) {
            Toggle(isOn: $options.extractAudio) {
                Text("Extract Audio Only")
                    .fontWeight(.semibold)
                    .foregroundColor(MacYTColors.textPrimary)
            }
            .toggleStyle(SwitchToggleStyle(tint: MacYTColors.accentGradientStart))
            .padding()
            
            if options.extractAudio {
                Divider()
                
                VStack(alignment: .leading, spacing: MacYTSpacing.md) {
                    HStack {
                        Text("Format:")
                            .foregroundColor(MacYTColors.textSecondary)
                        Spacer()
                        Picker("", selection: $options.audioFormat) {
                            Text("MP3").tag("mp3")
                            Text("M4A").tag("m4a")
                            Text("FLAC").tag("flac")
                            Text("AAC").tag("aac")
                            Text("WAV").tag("wav")
                            Text("Opus").tag("opus")
                        }
                        .frame(width: 100)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Quality:")
                                .foregroundColor(MacYTColors.textSecondary)
                            Spacer()
                            Text(options.audioQuality == 0 ? "Best (V0)" : "\(options.audioQuality)")
                                .font(.caption)
                                .foregroundColor(MacYTColors.accentGradientStart)
                        }
                        
                        Slider(value: Binding(
                            get: { Double(options.audioQuality) },
                            set: { options.audioQuality = Int($0) }
                        ), in: 0...9, step: 1)
                        .tint(MacYTColors.accentGradientStart)
                        
                        HStack {
                            Text("Best").font(.caption2).foregroundColor(MacYTColors.textSecondary)
                            Spacer()
                            Text("Smallest").font(.caption2).foregroundColor(MacYTColors.textSecondary)
                        }
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(MacYTCornerRadius.medium)
                .padding()
            }
        }
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(MacYTCornerRadius.large)
        .overlay(
            RoundedRectangle(cornerRadius: MacYTCornerRadius.large)
                .stroke(MacYTColors.separator, lineWidth: 0.5)
        )
    }
}
