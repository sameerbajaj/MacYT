import SwiftUI

struct ExportedFilesView: View {
    let directory: URL

    @State private var files: [ExportedFileItem] = []
    @State private var lastError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: MacYTSpacing.lg) {
            HStack {
                Text("Downloaded files")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(MacYTColors.textPrimary)

                Spacer(minLength: 0)

                Button("Refresh") {
                    loadFiles()
                }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(MacYTColors.accentGradientEnd)
            }

            Text(directory.path)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(MacYTColors.textTertiary)

            if let lastError {
                Text(lastError)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(MacYTColors.destructive)
            }

            if files.isEmpty {
                Text("No exported files found yet in this folder.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(MacYTColors.textSecondary)
                    .padding(MacYTSpacing.lg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: MacYTCornerRadius.large, style: .continuous))
            } else {
                ForEach(files) { file in
                    HStack(spacing: MacYTSpacing.md) {
                        Image(systemName: "doc.fill")
                            .foregroundColor(MacYTColors.accentGradientEnd)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(file.name)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(MacYTColors.textPrimary)
                                .lineLimit(1)

                            Text("\(file.sizeLabel) • \(file.modifiedLabel)")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundColor(MacYTColors.textTertiary)
                        }

                        Spacer(minLength: 0)

                        Button("Reveal") {
                            NSWorkspace.shared.activateFileViewerSelecting([file.url])
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(MacYTColors.accentGradientEnd)
                    }
                    .padding(.horizontal, MacYTSpacing.md)
                    .padding(.vertical, MacYTSpacing.md)
                    .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: MacYTCornerRadius.large, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: MacYTCornerRadius.large, style: .continuous)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )
                }
            }
        }
        .padding(MacYTSpacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .macYTCard()
        .onAppear(perform: loadFiles)
        .onChange(of: directory.path) { _, _ in
            loadFiles()
        }
    }

    private func loadFiles() {
        do {
            let values: Set<URLResourceKey> = [.isRegularFileKey, .contentModificationDateKey, .fileSizeKey]
            let urls = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: Array(values),
                options: [.skipsHiddenFiles]
            )

            let mapped = urls.compactMap { url -> ExportedFileItem? in
                guard let resourceValues = try? url.resourceValues(forKeys: values),
                      resourceValues.isRegularFile == true else {
                    return nil
                }

                return ExportedFileItem(
                    url: url,
                    name: url.lastPathComponent,
                    modifiedAt: resourceValues.contentModificationDate ?? .distantPast,
                    sizeBytes: Int64(resourceValues.fileSize ?? 0)
                )
            }

            files = mapped.sorted { $0.modifiedAt > $1.modifiedAt }
            lastError = nil
        } catch {
            files = []
            lastError = "Could not read exported files in the selected folder."
        }
    }
}

private struct ExportedFileItem: Identifiable {
    let id = UUID()
    let url: URL
    let name: String
    let modifiedAt: Date
    let sizeBytes: Int64

    var sizeLabel: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }

    var modifiedLabel: String {
        ExportedFileItem.dateFormatter.string(from: modifiedAt)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}
