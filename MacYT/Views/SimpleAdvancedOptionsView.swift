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
                    Toggle("Embed metadata", isOn: $options.embedMetadata)
                    Toggle("Embed chapters", isOn: $options.embedChapters)
                    Toggle("Embed thumbnail", isOn: $options.embedThumbnail)
                    Toggle("Split by chapters", isOn: $options.splitChapters)
                    Toggle("Use SponsorBlock", isOn: $options.sponsorBlock)

                    if options.sponsorBlock {
                        Picker("SponsorBlock action", selection: $options.sponsorBlockAction) {
                            Text("Mark").tag("mark")
                            Text("Remove").tag("remove")
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 240)
                    }
                }
                .toggleStyle(.switch)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(MacYTColors.textSecondary)
            } else {
                Text("SponsorBlock, chapters, metadata and related controls live here.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(MacYTColors.textSecondary)
            }
        }
        .padding(MacYTSpacing.xl)
        .macYTCard()
    }
}
