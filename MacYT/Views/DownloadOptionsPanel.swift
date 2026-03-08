import SwiftUI

struct DownloadOptionsPanel: View {
    @ObservedObject var options: DownloadOptions
    
    var body: some View {
        VStack(alignment: .leading, spacing: MacYTSpacing.lg) {
            MacYTSectionHeading(
                eyebrow: "Control booth",
                title: "Export options",
                subtitle: "Start with the kind of file you want, then adjust only the options that matter for that path."
            )

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: MacYTSpacing.xl) {
                    AudioExtractionView(options: options)

                    SectionView(title: "Save to", icon: "folder.fill") {
                        VStack(alignment: .leading, spacing: MacYTSpacing.sm) {
                            Text("Output Directory")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .tracking(1.0)
                                .foregroundColor(MacYTColors.textTertiary)

                            HStack {
                                Text(options.outputDirectory.lastPathComponent)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                    .foregroundColor(MacYTColors.textPrimary)

                                Spacer()

                                Button("Change…") {
                                    let panel = NSOpenPanel()
                                    panel.canChooseFiles = false
                                    panel.canChooseDirectories = true
                                    panel.canCreateDirectories = true
                                    if panel.runModal() == .OK, let url = panel.url {
                                        options.outputDirectory = url
                                    }
                                }
                                .buttonStyle(.plain)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(MacYTColors.accentGradientEnd)
                            }
                            .macYTControlSurface()
                        }
                    }

                    DisclosureGroup {
                        VStack(alignment: .leading, spacing: MacYTSpacing.xl) {
                            SectionView(title: "Metadata & Info", icon: "tag.fill") {
                                ControlToggleRow(title: "Embed Metadata", isOn: $options.embedMetadata)
                                ControlToggleRow(title: "Embed Chapters", isOn: $options.embedChapters)
                                ControlToggleRow(title: "Embed Thumbnail", isOn: $options.embedThumbnail)
                            }

                            if !options.extractAudio {
                                SectionView(title: "Subtitles", icon: "captions.bubble.fill") {
                                    ControlToggleRow(title: "Write Subtitles", isOn: $options.writeSubs)
                                    ControlToggleRow(title: "Auto-generated Subs", isOn: $options.writeAutoSubs)

                                    if options.writeSubs || options.writeAutoSubs {
                                        ControlPickerRow(title: "Language") {
                                            Picker("", selection: $options.subLanguage) {
                                                Text("English (en)").tag("en")
                                                Text("Spanish (es)").tag("es")
                                                Text("French (fr)").tag("fr")
                                                Text("German (de)").tag("de")
                                                Text("Japanese (ja)").tag("ja")
                                                Text("Korean (ko)").tag("ko")
                                                Text("All").tag("all")
                                            }
                                            .labelsHidden()
                                            .frame(width: 130)
                                        }

                                        ControlToggleRow(title: "Convert Format", isOn: $options.convertSubsToEmber)

                                        if options.convertSubsToEmber {
                                            ControlPickerRow(title: "Target Format") {
                                                Picker("Target Format", selection: $options.convertSubsFormat) {
                                                    Text("SRT").tag("srt")
                                                    Text("VTT").tag("vtt")
                                                    Text("ASS").tag("ass")
                                                }
                                                .labelsHidden()
                                                .frame(width: 110)
                                            }
                                        }
                                    }
                                }
                            }

                            SectionView(title: "Extras", icon: "slider.horizontal.3") {
                                ControlToggleRow(title: "Enable SponsorBlock", isOn: $options.sponsorBlock)

                                if options.sponsorBlock {
                                    ControlPickerRow(title: "Action") {
                                        Picker("Action", selection: $options.sponsorBlockAction) {
                                            Text("Mark as Chapters").tag("mark")
                                            Text("Remove Segments").tag("remove")
                                        }
                                        .labelsHidden()
                                        .frame(width: 150)
                                    }
                                }

                                ControlToggleRow(title: "Split by Chapters", isOn: $options.splitChapters)
                            }
                        }
                        .padding(.top, MacYTSpacing.md)
                    } label: {
                        HStack(spacing: MacYTSpacing.sm) {
                            Image(systemName: "gearshape.2.fill")
                                .foregroundColor(MacYTColors.accentGradientEnd)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Advanced options")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(MacYTColors.textPrimary)
                                Text("Metadata, subtitles, cleanup, and chapter tools.")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundColor(MacYTColors.textSecondary)
                            }
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
                    .tint(MacYTColors.textPrimary)

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
        .environment(\.colorScheme, .dark)
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

private struct ControlToggleRow: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(MacYTColors.textPrimary)
        }
        .toggleStyle(SwitchToggleStyle(tint: MacYTColors.accentGradientStart))
        .macYTControlSurface()
    }
}

private struct ControlPickerRow<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(MacYTColors.textPrimary)

            Spacer()

            content()
        }
        .macYTControlSurface()
    }
}
