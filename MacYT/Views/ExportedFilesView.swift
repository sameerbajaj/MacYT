import SwiftUI

@MainActor
struct ExportedFilesView: View {
    var outputDirectory: URL = DownloadOptions.defaultOutputDirectory()
    @ObservedObject private var historyStore = DownloadHistoryStore.shared
    var onNavigateToStudio: (() -> Void)? = nil
    @State private var files: [ExportedFileItem] = []

    var body: some View {
        VStack(alignment: .leading, spacing: MacYTSpacing.lg) {
            HStack {
                Text("MacYT downloads")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(MacYTColors.textPrimary)

                Spacer(minLength: 0)

                Button {
                    NSWorkspace.shared.open(outputDirectory)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "folder.fill")
                        Text("Open Folder")
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(MacYTColors.accentGradientEnd)

                Button("Refresh") {
                    loadHistory()
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
                VStack(alignment: .leading, spacing: MacYTSpacing.md) {
                    Image(systemName: "tray.and.arrow.down.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(MacYTColors.accentGradientEnd)

                    Text("No MacYT exports found yet.")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(MacYTColors.textPrimary)

                    Text("Files downloaded with MacYT will appear here. Paste a link in Studio to start an export.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(MacYTColors.textSecondary)
                        .frame(maxWidth: 480, alignment: .leading)

                    HStack(spacing: MacYTSpacing.md) {
                        if let onNavigateToStudio {
                            GradientButton(title: "Go to Studio", icon: "sparkles.tv.fill", isLoading: false) {
                                onNavigateToStudio()
                            }
                            .frame(height: 44)
                        }

                        Button {
                            NSWorkspace.shared.open(outputDirectory)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "folder")
                                Text("Open Destination Folder")
                            }
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(MacYTColors.textPrimary)
                            .padding(.horizontal, MacYTSpacing.md)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: MacYTCornerRadius.medium, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 4)
                }
                .padding(MacYTSpacing.xl)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: MacYTCornerRadius.large, style: .continuous))
            } else {
                LazyVStack(spacing: MacYTSpacing.md) {
                    ForEach(files) { file in
                        HStack(spacing: MacYTSpacing.md) {
                            Image(systemName: "doc.fill")
                                .font(.system(size: 18))
                                .foregroundColor(MacYTColors.accentGradientEnd)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(file.name)
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(MacYTColors.textPrimary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)

                                Text("\(file.sizeLabel) • \(file.modifiedLabel)")
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundColor(MacYTColors.textTertiary)

                                Text(file.parentDirectoryPath)
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundColor(MacYTColors.textTertiary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            HStack(spacing: 8) {
                                Button("Open") {
                                    NSWorkspace.shared.open(file.url)
                                }
                                .buttonStyle(.plain)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(MacYTColors.textSecondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                                Button("Reveal") {
                                    NSWorkspace.shared.activateFileViewerSelecting([file.url])
                                }
                                .buttonStyle(.plain)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(MacYTColors.accentGradientEnd)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(MacYTColors.accentGradientEnd.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                                Button {
                                    historyStore.removeRecord(id: file.id)
                                } label: {
                                    Image(systemName: "xmark.circle")
                                        .font(.system(size: 14))
                                        .foregroundColor(MacYTColors.textTertiary)
                                }
                                .buttonStyle(.plain)
                                .help("Remove from history")
                                .padding(.leading, 2)
                            }
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
        }
        .padding(MacYTSpacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .macYTCard()
        .onAppear(perform: loadHistory)
        .onReceive(historyStore.$records) { newRecords in
            files = newRecords.compactMap(ExportedFileItem.init)
        }
    }

    private func loadHistory() {
        historyStore.refresh()
        files = historyStore.records.compactMap(ExportedFileItem.init)
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
