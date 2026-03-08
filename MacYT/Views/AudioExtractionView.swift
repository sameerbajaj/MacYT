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
                    Image(systemName: "music.note.list")
                        .foregroundColor(MacYTColors.accentGradientEnd)
                    Text("Audio extraction")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(MacYTColors.textPrimary)
                }

                Text("Flip MacYT into an audio-first workflow when you only need the soundtrack, podcast track, or music rip.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(MacYTColors.textSecondary)
            }

            Spacer()

            Toggle("", isOn: $options.extractAudio)
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle(tint: MacYTColors.accentGradientStart))
        }
    }

    private var settingsCard: some View {
        VStack(alignment: .leading, spacing: MacYTSpacing.md) {
            HStack {
                Text("Format")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
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
                .frame(width: 110)
            }

            qualityControls
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

    private var qualityControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Quality")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(MacYTColors.textSecondary)
                Spacer()
                Text(options.audioQuality == 0 ? "Best (V0)" : "\(options.audioQuality)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(MacYTColors.accentGradientEnd)
            }

            Slider(value: audioQualityBinding, in: 0...9, step: 1)
                .tint(MacYTColors.accentGradientStart)

            HStack {
                Text("Best")
                Spacer()
                Text("Smallest")
            }
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundColor(MacYTColors.textTertiary)
        }
    }

    private var disabledBanner: some View {
        MacYTInlineBanner(
            icon: "film.fill",
            title: "Video-first mode",
            message: "You are currently set up to download video assets. Turn this on when you want audio-only exports instead.",
            tint: MacYTColors.accentGradientEnd
        )
    }

    private var audioQualityBinding: Binding<Double> {
        Binding(
            get: { Double(options.audioQuality) },
            set: { options.audioQuality = Int($0) }
        )
    }
}
