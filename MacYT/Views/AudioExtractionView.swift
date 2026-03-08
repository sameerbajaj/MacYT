import SwiftUI

struct AudioExtractionView: View {
    @ObservedObject var options: DownloadOptions
    
    var body: some View {
        VStack(alignment: .leading, spacing: MacYTSpacing.md) {
            header

            if options.extractAudio {
                settingsCard
            } else {
                disabledBanner
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

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: MacYTSpacing.sm) {
                    Image(systemName: options.extractAudio ? "music.note.list" : "play.rectangle.fill")
                        .foregroundColor(MacYTColors.accentGradientEnd)
                    Text("What are you saving?")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(MacYTColors.textPrimary)
                }

                Text("Choose a simple export path first. Video keeps the picture. Audio grabs the best source track and converts it for you.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(MacYTColors.textSecondary)
            }

            Spacer()

            Picker("", selection: exportModeBinding) {
                Text("Video").tag(false)
                Text("Audio").tag(true)
            }
            .pickerStyle(.segmented)
            .frame(width: 170)
        }
    }

    private var settingsCard: some View {
        VStack(alignment: .leading, spacing: MacYTSpacing.md) {
            HStack {
                Text("Format")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(MacYTColors.textPrimary)

                Spacer()

                Picker("", selection: $options.audioFormat) {
                    Text("MP3").tag("mp3")
                    Text("M4A").tag("m4a")
                    Text("FLAC").tag("flac")
                    Text("AAC").tag("aac")
                    Text("WAV").tag("wav")
                    Text("Opus").tag("opus")
                }
                .labelsHidden()
                .frame(width: 110)
            }
            .macYTControlSurface()

            bitrateControls

            MacYTInlineBanner(
                icon: "waveform.badge.magnifyingglass",
                title: "No stream picking needed",
                message: "MacYT will automatically grab the best available source audio, then convert it into your chosen format.",
                tint: MacYTColors.accentGradientEnd
            )
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

    private var bitrateControls: some View {
        VStack(alignment: .leading, spacing: MacYTSpacing.sm) {
            Text("Bitrate")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(MacYTColors.textPrimary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: MacYTSpacing.sm) {
                ForEach(AudioBitratePreset.allCases) { preset in
                    Button {
                        options.audioBitrate = preset
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(preset.label)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(MacYTColors.textPrimary)

                            Text(preset.description)
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(MacYTColors.textSecondary)
                                .multilineTextAlignment(.leading)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, MacYTSpacing.md)
                        .padding(.vertical, MacYTSpacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: MacYTCornerRadius.medium, style: .continuous)
                                .fill(options.audioBitrate == preset ? MacYTColors.accentGlow.opacity(0.22) : Color.white.opacity(0.04))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: MacYTCornerRadius.medium, style: .continuous)
                                .stroke(options.audioBitrate == preset ? MacYTColors.accentGradientEnd.opacity(0.65) : Color.white.opacity(0.08), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .macYTControlSurface()
    }

    private var disabledBanner: some View {
        MacYTInlineBanner(
            icon: "film.fill",
            title: "Video mode",
            message: "You will pick a video quality on the left, then download the final video without extra audio conversion settings getting in the way.",
            tint: MacYTColors.accentGradientEnd
        )
    }

    private var exportModeBinding: Binding<Bool> {
        Binding(
            get: { options.extractAudio },
            set: { options.extractAudio = $0 }
        )
    }
}
