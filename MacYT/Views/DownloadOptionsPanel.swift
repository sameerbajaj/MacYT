import SwiftUI

struct DownloadOptionsPanel: View {
    @ObservedObject var options: DownloadOptions
    
    var body: some View {
        VStack(alignment: .leading, spacing: MacYTSpacing.lg) {
            MacYTSectionHeading(
                eyebrow: "Control booth",
                title: "Export options",
                subtitle: "Dial in metadata, subtitle handling, audio extraction, and output behavior before you commit the download."
            )

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: MacYTSpacing.xl) {
                AudioExtractionView(options: options)

                    SectionView(title: "Metadata & Info", icon: "tag.fill") {
                    Toggle("Embed Metadata", isOn: $options.embedMetadata)
                    Toggle("Embed Chapters", isOn: $options.embedChapters)
                    Toggle("Embed Thumbnail", isOn: $options.embedThumbnail)
                }

                    SectionView(title: "Subtitles", icon: "captions.bubble.fill") {
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

                    SectionView(title: "SponsorBlock", icon: "scissors.badge.ellipsis") {
                    Toggle("Enable SponsorBlock", isOn: $options.sponsorBlock)
                    if options.sponsorBlock {
                        Picker("Action", selection: $options.sponsorBlockAction) {
                            Text("Mark as Chapters").tag("mark")
                            Text("Remove Segments").tag("remove")
                        }
                    }
                }

                    SectionView(title: "Output", icon: "shippingbox.fill") {
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
                            .buttonStyle(.plain)
                            .foregroundColor(MacYTColors.accentGradientEnd)
                        }
                    }
                }

                    Spacer(minLength: 40)
                }
                .toggleStyle(SwitchToggleStyle(tint: MacYTColors.accentGradientStart))
            }
            .padding(.top, 2)
        }
        .padding(MacYTSpacing.xl)
        .frame(width: 340)
        .frame(maxHeight: .infinity, alignment: .top)
        .macYTCard()
    }
}

private struct SectionView<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: MacYTSpacing.md) {
            HStack(spacing: MacYTSpacing.sm) {
                Image(systemName: icon)
                    .foregroundColor(MacYTColors.accentGradientEnd)
                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(MacYTColors.textPrimary)
            }
            
            VStack(alignment: .leading, spacing: MacYTSpacing.md) {
                content()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: MacYTCornerRadius.large, style: .continuous)
                    .fill(Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: MacYTCornerRadius.large, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
        }
    }
}
