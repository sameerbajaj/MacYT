import SwiftUI

struct DownloadOptionsPanel: View {
    @ObservedObject var options: DownloadOptions
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MacYTSpacing.xl) {
                
                // Audio Extraction
                AudioExtractionView(options: options)
                
                // Metadata
                SectionView(title: "Metadata & Info") {
                    Toggle("Embed Metadata", isOn: $options.embedMetadata)
                    Toggle("Embed Chapters", isOn: $options.embedChapters)
                    Toggle("Embed Thumbnail", isOn: $options.embedThumbnail)
                }
                
                // Subtitles
                SectionView(title: "Subtitles") {
                    Toggle("Write Subtitles (Subs)", isOn: $options.writeSubs)
                    Toggle("Auto-generated Subs", isOn: $options.writeAutoSubs)
                    
                    if options.writeSubs || options.writeAutoSubs {
                        HStack {
                            Text("Language")
                            Spacer()
                            Picker("", selection: $options.subLanguage) {
                                Text("English (en)").tag("en")
                                Text("Spanish (es)").tag("es")
                                Text("French (fr)").tag("fr")
                                Text("German (de)").tag("de")
                                Text("Japanese (ja)").tag("ja")
                                Text("Korean (ko)").tag("ko")
                                Text("All").tag("all")
                            }
                            .frame(width: 120)
                        }
                        
                        Toggle("Convert Format", isOn: $options.convertSubsToEmber)
                        if options.convertSubsToEmber {
                            Picker("Target Format", selection: $options.convertSubsFormat) {
                                Text("SRT").tag("srt")
                                Text("VTT").tag("vtt")
                                Text("ASS").tag("ass")
                            }
                        }
                    }
                }
                
                // SponsorBlock
                SectionView(title: "SponsorBlock") {
                    Toggle("Enable SponsorBlock", isOn: $options.sponsorBlock)
                    if options.sponsorBlock {
                        Picker("Action", selection: $options.sponsorBlockAction) {
                            Text("Mark as Chapters").tag("mark")
                            Text("Remove Segments").tag("remove")
                        }
                    }
                }
                
                // Output
                SectionView(title: "Output") {
                    Toggle("Split by Chapters", isOn: $options.splitChapters)
                    
                    VStack(alignment: .leading) {
                        Text("Output Directory")
                            .font(.caption)
                            .foregroundColor(MacYTColors.textSecondary)
                        HStack {
                            Text(options.outputDirectory.lastPathComponent)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .font(.system(.body, design: .monospaced))
                            
                            Spacer()
                            
                            Button("Change...") {
                                let panel = NSOpenPanel()
                                panel.canChooseFiles = false
                                panel.canChooseDirectories = true
                                panel.canCreateDirectories = true
                                if panel.runModal() == .OK, let url = panel.url {
                                    options.outputDirectory = url
                                }
                            }
                        }
                    }
                }
                
                Spacer(minLength: 40)
            }
            .padding()
            .toggleStyle(SwitchToggleStyle(tint: MacYTColors.accentGradientStart))
        }
        .frame(width: 280)
        .background(Color(NSColor.windowBackgroundColor))
        .overlay(
            Rectangle()
                .fill(MacYTColors.separator)
                .frame(width: 0.5), alignment: .leading
        )
    }
}

private struct SectionView<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: MacYTSpacing.md) {
            Text(title)
                .font(.headline)
                .foregroundColor(MacYTColors.textPrimary)
            
            VStack(alignment: .leading, spacing: MacYTSpacing.md) {
                content()
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(MacYTCornerRadius.large)
            .shadow(color: Color.black.opacity(0.02), radius: 2, y: 1)
        }
    }
}
