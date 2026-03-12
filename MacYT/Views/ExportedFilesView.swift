import SwiftUI

@MainActor
struct ExportedFilesView: View {
    @ObservedObject private var historyStore = DownloadHistoryStore.shared

    private var files: [ExportedFileItem] {
        historyStore.records.compactMap(ExportedFileItem.init)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MacYTSpacing.lg) {
            HStack {
                Text("MacYT downloads")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(MacYTColors.textPrimary)

                Spacer(minLength: 0)

                Button("Refresh") {
                    historyStore.refresh()
                }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(MacYTColors.accentGradientEnd)
            }

            Text("Only files exported by MacYT appear here, even if you changed the destination folder.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(MacYTColors.textSecondary)

            if let lastError = historyStore.lastError {
                Text(lastError)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(MacYTColors.destructive)
            }

            if files.isEmpty {
                Text("No MacYT exports found yet.")
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

                            Text(file.parentDirectoryPath)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundColor(MacYTColors.textTertiary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }

                        Spacer(minLength: 0)

                        Button("Open") {
                            NSWorkspace.shared.open(file.url)
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(MacYTColors.textSecondary)

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
        .onAppear(perform: historyStore.refresh)
    }
}

private struct ExportedFileItem: Identifiable {
    let id: String
    let url: URL
    let name: String
    let modifiedAt: Date
    let sizeBytes: Int64
    let parentDirectoryPath: String

    init?(record: DownloadHistoryRecord) {
        let url = URL(fileURLWithPath: record.filePath)
        let values: Set<URLResourceKey> = [.isRegularFileKey, .contentModificationDateKey, .fileSizeKey]

        guard let resourceValues = try? url.resourceValues(forKeys: values),
              resourceValues.isRegularFile == true else {
            return nil
        }

        self.id = record.id
        self.url = url
        self.name = url.lastPathComponent
        self.modifiedAt = resourceValues.contentModificationDate ?? record.downloadedAt
        self.sizeBytes = Int64(resourceValues.fileSize ?? 0)
        self.parentDirectoryPath = url.deletingLastPathComponent().path
    }

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
