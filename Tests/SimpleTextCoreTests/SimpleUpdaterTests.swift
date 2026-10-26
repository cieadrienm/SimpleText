import Foundation
import Testing
@testable import SimpleTextCore

@Suite("SimpleUpdater")
struct SimpleUpdaterTests {
    @Test("Semantic version and build comparison")
    func versionComparison() {
        #expect(SimpleUpdater.compareVersions("1.1.0", "1.0.0") == .orderedDescending)
        #expect(SimpleUpdater.compareVersions("v1.0.0", "1.0") == .orderedSame)
        #expect(SimpleUpdater.compareVersions("0.11.0", "0.12.0") == .orderedAscending)
        #expect(SimpleUpdater.compareVersions("2.0", "1.9.9") == .orderedDescending)

        #expect(SimpleUpdater.isNewer(remoteVersion: "1.1.0", currentVersion: "1.0.0"))
        #expect(!SimpleUpdater.isNewer(remoteVersion: "1.0.0", currentVersion: "1.0.0"))
        #expect(SimpleUpdater.isNewer(remoteVersion: "1.0.0", remoteBuild: 15, currentVersion: "1.0.0", currentBuild: 10))
        #expect(!SimpleUpdater.isNewer(remoteVersion: "1.0.0", remoteBuild: 10, currentVersion: "1.0.0", currentBuild: 10))
        #expect(!SimpleUpdater.isNewer(remoteVersion: "0.9.0", remoteBuild: 99, currentVersion: "1.0.0", currentBuild: 1))
    }

    @Test("Multi-app and single-app JSON manifest parsing with bilingual release notes")
    func manifestParsing() throws {
        let multiJSON = """
        {
          "net.cieadrienm.simpletext": {
            "version": "v1.2.0",
            "build": 42,
            "url": "https://example.com/SimpleText-1.2.0.zip",
            "sha256": "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
            "notes_fr": "Corrections et améliorations.",
            "notes_en": "Bug fixes and improvements."
          }
        }
        """.data(using: .utf8)!

        let release = try SimpleUpdater.parseManifest(multiJSON)
        #expect(release.version == "1.2.0")
        #expect(release.build == 42)
        #expect(release.downloadURL.absoluteString == "https://example.com/SimpleText-1.2.0.zip")
        #expect(release.sha256 == "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef")

        #expect(release.notes(for: .fr) == "Corrections et améliorations.")
        #expect(release.notes(for: .en) == "Bug fixes and improvements.")

        let singleJSON = """
        {
          "version": "1.3.0",
          "url": "https://example.com/SimpleText-1.3.0.zip",
          "notes": "Single manifest note"
        }
        """.data(using: .utf8)!
        let single = try SimpleUpdater.parseManifest(singleJSON)
        #expect(single.version == "1.3.0")
        #expect(single.build == nil)
        #expect(single.localizedNotes == "Single manifest note")
    }

    @Test("GitHub Releases API JSON parsing")
    func githubReleaseParsing() throws {
        let githubJSON = """
        {
          "tag_name": "v1.4.2",
          "html_url": "https://github.com/cieadrienm/SimpleText/releases/tag/v1.4.2",
          "published_at": "2026-10-25T10:00:00Z",
          "body": "### Changes\\n- Fast startup\\nSHA-256: `aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa`",
          "assets": [
            {
              "name": "SimpleText-1.4.2.dmg",
              "browser_download_url": "https://github.com/cieadrienm/SimpleText/releases/download/v1.4.2/SimpleText-1.4.2.dmg"
            },
            {
              "name": "SimpleText-1.4.2.zip",
              "browser_download_url": "https://github.com/cieadrienm/SimpleText/releases/download/v1.4.2/SimpleText-1.4.2.zip"
            }
          ]
        }
        """.data(using: .utf8)!

        let release = try SimpleUpdater.parseGitHubRelease(githubJSON)
        #expect(release.version == "1.4.2")
        #expect(release.downloadURL.absoluteString == "https://github.com/cieadrienm/SimpleText/releases/download/v1.4.2/SimpleText-1.4.2.zip")
        #expect(release.sha256 == "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
        #expect(release.htmlURL?.absoluteString == "https://github.com/cieadrienm/SimpleText/releases/tag/v1.4.2")

        let noZipJSON = """
        {
          "tag_name": "v1.4.2",
          "assets": []
        }
        """.data(using: .utf8)!
        #expect(throws: SimpleUpdater.UpdaterError.noZipAssetFound) {
            try SimpleUpdater.parseGitHubRelease(noZipJSON)
        }
    }

    @Test("Endpoint resolution honours env var, UserDefaults, Info.plist, and GitHub fallback")
    func endpointResolution() throws {
        let suiteName = "net.cieadrienm.simpletext.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        // 1. Default fallback -> GitHub Releases API
        let fallback = try SimpleUpdater.resolveEndpoint(
            repo: "cieadrienm/SimpleText",
            environment: [:],
            defaults: defaults,
            infoDictionary: [:]
        )
        #expect(fallback == .githubLatestRelease(URL(string: "https://api.github.com/repos/cieadrienm/SimpleText/releases/latest")!))

        // 2. Info.plist SimpleUpdateURL
        let plistEndpoint = try SimpleUpdater.resolveEndpoint(
            environment: [:],
            defaults: defaults,
            infoDictionary: ["SimpleUpdateURL": "https://updates.example.com/plist.json"]
        )
        #expect(plistEndpoint == .customManifest(URL(string: "https://updates.example.com/plist.json")!))

        // 3. UserDefaults overrides Info.plist
        defaults.set("https://updates.example.com/defaults.json", forKey: SimpleUpdater.updateURLKey)
        let defaultsEndpoint = try SimpleUpdater.resolveEndpoint(
            environment: [:],
            defaults: defaults,
            infoDictionary: ["SimpleUpdateURL": "https://updates.example.com/plist.json"]
        )
        #expect(defaultsEndpoint == .customManifest(URL(string: "https://updates.example.com/defaults.json")!))

        // 4. Environment variable overrides all
        let envEndpoint = try SimpleUpdater.resolveEndpoint(
            environment: ["SIMPLE_UPDATE_URL": "https://updates.example.com/env.json"],
            defaults: defaults,
            infoDictionary: ["SimpleUpdateURL": "https://updates.example.com/plist.json"]
        )
        #expect(envEndpoint == .customManifest(URL(string: "https://updates.example.com/env.json")!))
    }

    @Test("Auto-check throttling to 24 hours")
    @MainActor
    func autoCheckThrottling() {
        let suiteName = "net.cieadrienm.simpletext.throttle.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let updater = SimpleUpdater(defaults: defaults)
        #expect(updater.autoCheckEnabled == true)
        #expect(updater.shouldAutoCheck())

        let now = Date()
        updater.lastCheckDate = now.addingTimeInterval(-3600) // 1 hour ago
        #expect(!updater.shouldAutoCheck(now: now))

        updater.lastCheckDate = now.addingTimeInterval(-(24 * 3600 + 10)) // > 24 hours ago
        #expect(updater.shouldAutoCheck(now: now))

        updater.autoCheckEnabled = false
        #expect(!updater.shouldAutoCheck(now: now))
    }

    @Test("SHA-256 verification, zip extraction, TeamIdentifier parsing, and helper script")
    func archiveAndSignatureHelpers() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("simpletext-updater-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Create a dummy .app inside a zip archive and test SHA-256 + ditto extraction + findAppBundle
        let sourceDir = tempDir.appendingPathComponent("src", isDirectory: true)
        let dummyApp = sourceDir.appendingPathComponent("SimpleText.app/Contents/MacOS", isDirectory: true)
        try FileManager.default.createDirectory(at: dummyApp, withIntermediateDirectories: true)
        let binaryURL = dummyApp.appendingPathComponent("SimpleText")
        try Data("#!/bin/sh\nexit 0\n".utf8).write(to: binaryURL)

        let zipURL = tempDir.appendingPathComponent("SimpleText.zip")
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        proc.arguments = ["-c", "-k", "--keepParent", sourceDir.appendingPathComponent("SimpleText.app").path, zipURL.path]
        try proc.run()
        proc.waitUntilExit()
        #expect(proc.terminationStatus == 0)

        let digest = try SimpleUpdater.sha256Hex(ofFile: zipURL)
        #expect(digest.count == 64)
        try SimpleUpdater.verifySHA256(fileURL: zipURL, expected: digest.uppercased())
        #expect(throws: SimpleUpdater.UpdaterError.self) {
            try SimpleUpdater.verifySHA256(fileURL: zipURL, expected: String(repeating: "0", count: 64))
        }

        let extractedDir = tempDir.appendingPathComponent("extracted", isDirectory: true)
        try SimpleUpdater.extractArchive(zipURL: zipURL, to: extractedDir)
        let foundApp = try SimpleUpdater.findAppBundle(in: extractedDir)
        #expect(foundApp.lastPathComponent == "SimpleText.app")

        // TeamIdentifier parsing
        let sampleCodesign = """
        Executable=/Applications/SimpleText.app/Contents/MacOS/SimpleText
        Identifier=net.cieadrienm.simpletext
        TeamIdentifier=ABCDE12345
        """
        #expect(SimpleUpdater.parseTeamIdentifier(fromCodesignOutput: sampleCodesign) == "ABCDE12345")
        #expect(SimpleUpdater.parseTeamIdentifier(fromCodesignOutput: "TeamIdentifier=not set\n") == nil)

        // Replacement shell script
        let cmd = SimpleUpdater.replacementShellCommand(newAppPath: "/tmp/stage/SimpleText.app", destinationAppPath: "/Applications/SimpleText.app")
        #expect(cmd.contains("ditto \"/tmp/stage/SimpleText.app\" \"/Applications/SimpleText.app\""))
        #expect(cmd.contains("xattr -dr com.apple.quarantine \"/Applications/SimpleText.app\""))
        #expect(cmd.contains("open \"/Applications/SimpleText.app\""))
    }
}
