import SwiftUI

struct SimpleAdvancedOptionsView: View {
    @ObservedObject var options: DownloadOptions
    @State private var showAdvanced = false

    var body: some View {
        VStack(alignment: .leading, spacing: MacYTSpacing.lg) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ADVANCED")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(1.4)
                        .foregroundColor(MacYTColors.accentGradientEnd)

                    Text("Optional tweaks")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(MacYTColors.textPrimary)
                }

                Spacer(minLength: 0)

                Button(showAdvanced ? "Hide" : "Show") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showAdvanced.toggle()
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(MacYTColors.accentGradientEnd)
            }

            if showAdvanced {
                VStack(alignment: .leading, spacing: MacYTSpacing.md) {
                    outputDirectoryRow

                    if !options.extractAudio {
                        HStack {
                            Text("Video container")
                            Spacer()
                            Picker("Video container", selection: $options.videoContainerPreference) {
                                ForEach(VideoContainerPreference.allCases) { preference in
                                    Text(preference.label).tag(preference)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .frame(width: 120)
                        }
                    }

                    Toggle("Embed metadata", isOn: $options.embedMetadata)
                    Toggle("Embed chapters", isOn: $options.embedChapters)
                    Toggle("Embed thumbnail", isOn: $options.embedThumbnail)
                    Toggle("Split by chapters", isOn: $options.splitChapters)
                    Toggle("Use SponsorBlock", isOn: $options.sponsorBlock)

                    if options.sponsorBlock {
                        HStack {
                            Text("SponsorBlock action")
                            Spacer()
                            Picker("SponsorBlock action", selection: $options.sponsorBlockAction) {
                                Text("Mark").tag("mark")
                                Text("Remove").tag("remove")
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                            .frame(width: 160)
                        }
                    }

                    Toggle("Download subtitles", isOn: $options.writeSubs)
                    Toggle("Auto-generated captions", isOn: $options.writeAutoSubs)

                    if options.writeSubs || options.writeAutoSubs {
                        HStack {
                            Text("Subtitle language")
                            Spacer()
                            Picker("Subtitle language", selection: $options.subLanguage) {
                                Text("English").tag("en")
                                Text("Spanish").tag("es")
                                Text("French").tag("fr")
                                Text("German").tag("de")
                                Text("Japanese").tag("ja")
                                Text("Korean").tag("ko")
                                Text("All").tag("all")
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .frame(width: 120)
                        }
                    }
                }
                .toggleStyle(.switch)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(MacYTColors.textSecondary)
            } else {
                HStack(spacing: MacYTSpacing.md) {
                    Text("Folder: \(options.outputDirectory.lastPathComponent) • Container, subtitles, SponsorBlock & metadata controls.")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(MacYTColors.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button("Change Folder…") {
                        chooseOutputDirectory()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(MacYTColors.accentGradientEnd)
                    .fixedSize()
                }
            }
        }
        .padding(MacYTSpacing.xl)
        .macYTCard()
    }

    private var outputDirectoryRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Save Destination")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(MacYTColors.textPrimary)
                Text(options.outputDirectory.path)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(MacYTColors.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: MacYTSpacing.md)

            Button("Open") {
                NSWorkspace.shared.open(options.outputDirectory)
            }
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundColor(MacYTColors.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            Button("Change…") {
                chooseOutputDirectory()
            }
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundColor(MacYTColors.accentGradientEnd)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(MacYTColors.accentGradientEnd.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .macYTControlSurface()
    }

    private func chooseOutputDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "Select Folder"
        if panel.runModal() == .OK, let url = panel.url {
            options.outputDirectory = url
        }
    }
}
