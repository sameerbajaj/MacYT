//
//  MacYTTests.swift
//  MacYTTests
//
//  Created by Sameer Bajaj on 3/8/26.
//

import Foundation
import Testing
@testable import MacYT

struct MacYTTests {

    @Test func videoFormatSimplifiedQualityLabels() {
        func makeFormat(height: Int?, res: String? = nil) -> VideoFormat {
            VideoFormat(
                formatId: "test",
                ext: "mp4",
                resolution: res,
                width: height.map { $0 * 16 / 9 },
                height: height,
                fps: 60,
                vcodec: "avc1",
                acodec: "mp4a",
                filesize: 1000,
                filesizeApprox: nil,
                tbr: 5000,
                formatNote: nil
            )
        }

        #expect(makeFormat(height: 4320).simplifiedQualityLabel == "8K")
        #expect(makeFormat(height: 2160).simplifiedQualityLabel == "4K")
        #expect(makeFormat(height: 1440).simplifiedQualityLabel == "1440p")
        #expect(makeFormat(height: 1080).simplifiedQualityLabel == "1080p")
        #expect(makeFormat(height: 720).simplifiedQualityLabel == "720p")
        #expect(makeFormat(height: 480).simplifiedQualityLabel == "480p")
        #expect(makeFormat(height: 360).simplifiedQualityLabel == "360p")
        #expect(makeFormat(height: 240).simplifiedQualityLabel == "240p")
        #expect(makeFormat(height: nil, res: "Custom").simplifiedQualityLabel == "Custom")
    }

    @Test func audioBitratePresets() {
        for preset in AudioBitratePreset.allCases {
            #expect(!preset.label.isEmpty)
            #expect(!preset.description.isEmpty)
            #expect(!preset.ytDLPValue.isEmpty)
        }
        #expect(AudioBitratePreset.best.ytDLPValue == "0")
        #expect(AudioBitratePreset.kb320.ytDLPValue == "320K")
        #expect(AudioBitratePreset.kb128.ytDLPValue == "128K")
    }

    @Test func subtitleOptionsFlags() {
        let options = DownloadOptions()
        options.writeSubs = true
        options.writeAutoSubs = true
        options.subLanguage = "es"

        let flags = options.commandLineFlags(requiresMerge: false)
        #expect(flags.contains("--write-subs"))
        #expect(flags.contains("--write-auto-subs"))
        #expect(flags.contains("--sub-langs"))
        #expect(flags.contains("es"))
    }

    @Test @MainActor func dismissDownloadStatusResetsToIdle() {
        let vm = AppViewModel()
        vm.downloadManager.status = .failed(error: "Simulated test error")
        vm.errorMessage = "Simulated test error"

        vm.dismissDownloadStatus()

        #expect(vm.downloadManager.status == .idle)
        #expect(vm.errorMessage == nil)
    }

    @Test func outputDirectoryPersistence() {
        let key = "MacYT_outputDirectoryPath"
        let savedOriginal = UserDefaults.standard.string(forKey: key)
        defer {
            UserDefaults.standard.set(savedOriginal, forKey: key)
        }

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("PersistenceTest-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let options = DownloadOptions()
        options.outputDirectory = tempDir

        #expect(UserDefaults.standard.string(forKey: key) == tempDir.path)
        #expect(DownloadOptions.defaultOutputDirectory().path == tempDir.path)

        try? FileManager.default.removeItem(at: tempDir)
    }
}
