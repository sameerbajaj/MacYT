import Foundation
import Testing
@testable import MacYT

struct DownloadOptionsTests {
    @Test
    func videoModeWithoutMergeDoesNotForceContainer() {
        let options = DownloadOptions()
        options.extractAudio = false
        options.videoContainerPreference = .mp4
        options.outputDirectory = temporaryOutputDirectory()

        let flags = options.commandLineFlags(requiresMerge: false)

        #expect(!flags.contains("--merge-output-format"))
    }

    @Test
    func videoModeMergeRespectsContainerPreference() {
        let options = DownloadOptions()
        options.extractAudio = false
        options.videoContainerPreference = .webm
        options.outputDirectory = temporaryOutputDirectory()

        let flags = options.commandLineFlags(requiresMerge: true)

        #expect(flags.contains("--merge-output-format"))
        #expect(flags.contains("webm"))
    }

    @Test
    func audioExtractionFlagsRemainUnchanged() {
        let options = DownloadOptions()
        options.extractAudio = true
        options.audioFormat = "m4a"
        options.audioBitrate = .kb192
        options.videoContainerPreference = .mp4
        options.outputDirectory = temporaryOutputDirectory()

        let flags = options.commandLineFlags(requiresMerge: true)

        #expect(flags.contains("-x"))
        #expect(flags.contains("--audio-format"))
        #expect(flags.contains("m4a"))
        #expect(flags.contains("--audio-quality"))
        #expect(flags.contains("192K"))
        #expect(!flags.contains("--merge-output-format"))
    }

    private func temporaryOutputDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("MacYTTests-\(UUID().uuidString)", isDirectory: true)
    }
}
