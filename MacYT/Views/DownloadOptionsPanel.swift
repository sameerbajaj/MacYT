import SwiftUI

struct DownloadOptionsPanel: View {
    @ObservedObject var options: DownloadOptions
    @State private var showAdvanced = false

    var body: some View {
        VStack(alignment: .leading, spacing: MacYTSpacing.xl) {
            MacYTSectionHeading(
                eyebrow: "Control booth",
                title: "Export options",
                subtitle: "Start with the kind of file you want, then adjust only the options that matter for that path."
            )

            modeCard
            saveCard
            advancedCard

            Spacer(minLength: 0)
        }
        .padding(MacYTSpacing.xl)
        .frame(width: 360)
        .frame(maxHeight: .infinity, alignment: .top)
        .macYTCard()
        .environment(\.colorScheme, .dark)
    }

    private var modeCard: some View {
        SidebarCard(title: "What are you saving?", icon: options.extractAudio ? "music.note" : "video.fill") {
            VStack(alignment: .leading, spacing: MacYTSpacing.lg) {
                Picker("Export type", selection: $options.extractAudio) {
                    Text("Video").tag(false)
                    Text("Audio").tag(true)
                }
                .pickerStyle(.segmented)

                if options.extractAudio {
                    VStack(alignment: .leading, spacing: MacYTSpacing.md) {
                        ControlPickerRow(title: "Format") {
                            Picker("Format", selection: $options.audioFormat) {
                                Text("MP3").tag("mp3")
                                Text("M4A").tag("m4a")
                                Text("FLAC").tag("flac")
                                Text("AAC").tag("aac")
                                Text("WAV").tag("wav")
                                Text("Opus").tag("opus")
                            }
                            .labelsHidden()
                            .frame(width: 120)
                        }

                        VStack(alignment: .leading, spacing: MacYTSpacing.sm) {
                            ControlPickerRow(title: "Bitrate") {
                                Picker("Bitrate", selection: $options.audioBitrate) {
                                    ForEach(AudioBitratePreset.allCases) { preset in
                                        Text(preset.label).tag(preset)
                                    }
                                }
                                .labelsHidden()
                                .frame(width: 140)
                            }

                            Text(options.audioBitrate.description)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(MacYTColors.textSecondary)
                                .padding(.horizontal, MacYTSpacing.xs)
                        }

                        SimpleInfoBanner(
                            icon: "waveform.circle.fill",
                            title: "No stream picking needed",
                            message: "MacYT will grab the best source audio track and convert it for you."
                        )
                    }
                } else {
                    SimpleInfoBanner(
                        icon: "film.stack.fill",
                        title: "Video mode",
                        message: "You will pick a video quality on the left, then download the final video without extra audio conversion settings getting in the way."
                    )
                }
            }
        }
    }

    private var saveCard: some View {
        SidebarCard(title: "Save to", icon: "folder.fill") {
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
    }

    private var advancedCard: some View {
        VStack(alignment: .leading, spacing: MacYTSpacing.md) {
            DisclosureGroup(isExpanded: $showAdvanced) {
                VStack(alignment: .leading, spacing: MacYTSpacing.lg) {
                    AdvancedSection(title: "Metadata", icon: "tag.fill") {
                        ControlToggleRow(title: "Embed Metadata", isOn: $options.embedMetadata)
                        ControlToggleRow(title: "Embed Chapters", isOn: $options.embedChapters)
                        ControlToggleRow(title: "Embed Thumbnail", isOn: $options.embedThumbnail)
                    }

                    AdvancedSection(title: "Subtitles", icon: "captions.bubble.fill") {
                        ControlToggleRow(title: "Write Subtitles", isOn: $options.writeSubs)
                        ControlToggleRow(title: "Auto-generated Subs", isOn: $options.writeAutoSubs)

                        if options.writeSubs || options.writeAutoSubs {
                            ControlPickerRow(title: "Language") {
                                Picker("Language", selection: $options.subLanguage) {
                                    Text("English").tag("en")
                                    Text("Spanish").tag("es")
                                    Text("French").tag("fr")
                                    Text("German").tag("de")
                                    Text("Japanese").tag("ja")
                                    Text("Korean").tag("ko")
                                    Text("All").tag("all")
                                }
                                .labelsHidden()
                                .frame(width: 120)
                            }

                            ControlToggleRow(title: "Convert Format", isOn: $options.convertSubsToEmber)

                            if options.convertSubsToEmber {
                                ControlPickerRow(title: "Subtitle Format") {
                                    Picker("Subtitle Format", selection: $options.convertSubsFormat) {
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

                    AdvancedSection(title: "Cleanup", icon: "scissors.badge.ellipsis") {
                        ControlToggleRow(title: "Enable SponsorBlock", isOn: $options.sponsorBlock)

                        if options.sponsorBlock {
                            ControlPickerRow(title: "Action") {
                                Picker("Action", selection: $options.sponsorBlockAction) {
                                    Text("Mark Chapters").tag("mark")
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
                HStack {
                    Text("Advanced options")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(MacYTColors.textPrimary)

                    Spacer()

                    Text(showAdvanced ? "Hide" : "Show")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(MacYTColors.accentGradientEnd)
                }
            }
            .tint(MacYTColors.textPrimary)
        }
        .padding(MacYTSpacing.lg)
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

private struct SidebarCard<Content: View>: View {
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

            content()
        }
        .padding(MacYTSpacing.lg)
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

private struct AdvancedSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: MacYTSpacing.md) {
            HStack(spacing: MacYTSpacing.sm) {
                Image(systemName: icon)
                    .foregroundColor(MacYTColors.accentGradientEnd)
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(MacYTColors.textPrimary)
            }

            content()
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

private struct SimpleInfoBanner: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: MacYTSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(MacYTColors.accentGradientEnd)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(MacYTColors.textPrimary)
                Text(message)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(MacYTColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(MacYTSpacing.md)
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
