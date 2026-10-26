import AppKit
import CryptoKit
import Foundation
import Observation

/// Lightweight, zero-dependency auto-updater for SimpleText.
/// Supports both a custom JSON manifest URL (single-app or multi-app keyed by bundle ID)
/// and the GitHub Releases API (`releases/latest`).
@MainActor
@Observable
public final class SimpleUpdater {
    public static let shared = SimpleUpdater()

    public nonisolated static let defaultRepo = "cieadrienm/SimpleText"
    public nonisolated static let defaultBundleID = "net.cieadrienm.simpletext"

    public nonisolated static let autoCheckKey = "net.cieadrienm.simpletext.autoCheckUpdates"
    public nonisolated static let lastCheckKey = "net.cieadrienm.simpletext.lastUpdateCheck"
    public nonisolated static let updateURLKey = "net.cieadrienm.simpletext.updateURL"
    public nonisolated static let infoPlistURLKey = "SimpleUpdateURL"
    public nonisolated static let envURLKey = "SIMPLE_UPDATE_URL"
    public nonisolated static let autoCheckInterval: TimeInterval = 24 * 60 * 60

    public nonisolated static let didChangeNotification = Notification.Name("net.cieadrienm.simpletext.updaterDidChange")

    public struct ReleaseInfo: Codable, Equatable, Sendable {
        public let version: String
        public let build: Int?
        public let downloadURL: URL
        public let sha256: String?
        public let notesFR: String?
        public let notesEN: String?
        public let htmlURL: URL?
        public let publishedAt: String?

        public var url: URL { downloadURL }

        public init(
            version: String,
            build: Int? = nil,
            downloadURL: URL,
            sha256: String? = nil,
            notesFR: String? = nil,
            notesEN: String? = nil,
            htmlURL: URL? = nil,
            publishedAt: String? = nil
        ) {
            self.version = SimpleUpdater.normalizeVersion(version)
            self.build = build
            self.downloadURL = downloadURL
            self.sha256 = sha256?.trimmingCharacters(in: .whitespacesAndNewlines)
            self.notesFR = notesFR
            self.notesEN = notesEN
            self.htmlURL = htmlURL
            self.publishedAt = publishedAt
        }

        public func notes(for language: AppLanguage = Localization.current) -> String {
            let preferred = language.isEnglish ? (notesEN ?? notesFR) : (notesFR ?? notesEN)
            let trimmed = preferred?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !trimmed.isEmpty { return trimmed }
            return language.isEnglish ? "No release notes provided." : "Aucune note de version fournie."
        }

        public var localizedNotes: String {
            notes(for: Localization.current)
        }

        public var displayVersion: String {
            if let build {
                return "v\(version) (\(build))"
            }
            return "v\(version)"
        }
    }

    public enum UpdaterError: LocalizedError, Equatable, Sendable {
        case invalidUpdateURL(String)
        case invalidHTTPStatus(Int)
        case malformedManifest(String)
        case noZipAssetFound
        case checksumMismatch(expected: String, actual: String)
        case extractionFailed(String)
        case appBundleNotFound
        case invalidCodeSignature(String)
        case teamIdentifierMismatch(expected: String, actual: String?)
        case installationFailed(String)

        public var errorDescription: String? {
            switch self {
            case .invalidUpdateURL(let raw):
                return L("URL de mise à jour invalide : \(raw)", "Invalid update URL: \(raw)")
            case .invalidHTTPStatus(let code):
                return L("Le serveur de mise à jour a répondu avec le code HTTP \(code).", "The update server returned HTTP status \(code).")
            case .malformedManifest(let detail):
                return L("Manifeste de mise à jour invalide (\(detail)).", "Malformed update manifest (\(detail)).")
            case .noZipAssetFound:
                return L("Aucune archive .zip trouvée dans la publication.", "No .zip archive found in the release.")
            case .checksumMismatch(let expected, let actual):
                return L(
                    "L’empreinte SHA-256 ne correspond pas (attendu : \(expected.prefix(12))…, reçu : \(actual.prefix(12))…).",
                    "SHA-256 checksum mismatch (expected: \(expected.prefix(12))…, got: \(actual.prefix(12))…)."
                )
            case .extractionFailed(let detail):
                return L("Échec de l’extraction de l’archive : \(detail)", "Failed to extract archive: \(detail)")
            case .appBundleNotFound:
                return L("Aucun paquet .app trouvé dans l’archive téléchargée.", "No .app bundle found inside the downloaded archive.")
            case .invalidCodeSignature(let detail):
                return L("Signature de code invalide : \(detail)", "Invalid code signature: \(detail)")
            case .teamIdentifierMismatch(let expected, let actual):
                return L(
                    "Identifiant d’équipe incohérent (attendu : \(expected), reçu : \(actual ?? "aucun")).",
                    "TeamIdentifier mismatch (expected: \(expected), got: \(actual ?? "none"))."
                )
            case .installationFailed(let detail):
                return L("Échec de l’installation : \(detail)", "Installation failed: \(detail)")
            }
        }
    }

    public enum State: Equatable, Sendable {
        case idle
        case checking
        case updateAvailable(ReleaseInfo)
        case upToDate(currentVersion: String)
        case downloading(ReleaseInfo)
        case installing(ReleaseInfo)
        case error(String)
    }

    public let repo: String
    public let bundleIdentifier: String
    private let defaults: UserDefaults
    private let session: URLSession

    public private(set) var state: State = .idle {
        didSet {
            NotificationCenter.default.post(name: Self.didChangeNotification, object: self)
        }
    }

    public private(set) var availableRelease: ReleaseInfo? {
        didSet {
            NotificationCenter.default.post(name: Self.didChangeNotification, object: self)
        }
    }

    /// Hook invoked when the updater wants to present the update UI (set by the app target).
    public var presentUpdateUI: (@MainActor () -> Void)?

    public init(
        repo: String = SimpleUpdater.defaultRepo,
        bundleIdentifier: String = SimpleUpdater.defaultBundleID,
        defaults: UserDefaults = .standard,
        session: URLSession = .shared
    ) {
        self.repo = repo
        self.bundleIdentifier = bundleIdentifier
        self.defaults = defaults
        self.session = session
    }

    // MARK: - Preferences

    public var autoCheckEnabled: Bool {
        get {
            if defaults.object(forKey: Self.autoCheckKey) == nil { return true }
            return defaults.bool(forKey: Self.autoCheckKey)
        }
        set {
            defaults.set(newValue, forKey: Self.autoCheckKey)
            NotificationCenter.default.post(name: Self.didChangeNotification, object: self)
        }
    }

    public var lastCheckDate: Date? {
        get {
            let ts = defaults.double(forKey: Self.lastCheckKey)
            return ts > 0 ? Date(timeIntervalSince1970: ts) : nil
        }
        set {
            if let newValue {
                defaults.set(newValue.timeIntervalSince1970, forKey: Self.lastCheckKey)
            } else {
                defaults.removeObject(forKey: Self.lastCheckKey)
            }
        }
    }

    // MARK: - Current Version

    public nonisolated static var currentVersionString: String {
        if let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
           !v.isEmpty, !v.hasPrefix("@") {
            return normalizeVersion(v)
        }
        return "0.11.0"
    }

    public nonisolated static var currentBuildNumber: Int? {
        if let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String,
           !b.isEmpty, !b.hasPrefix("@"),
           let num = Int(b.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return num
        }
        return nil
    }

    // MARK: - Endpoint Resolution

    public enum Endpoint: Equatable, Sendable {
        case customManifest(URL)
        case githubLatestRelease(URL)

        public var url: URL {
            switch self {
            case .customManifest(let url), .githubLatestRelease(let url):
                return url
            }
        }
    }

    public nonisolated static func resolveEndpoint(
        repo: String = defaultRepo,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        defaults: UserDefaults = .standard,
        infoDictionary: [String: Any]? = Bundle.main.infoDictionary
    ) throws -> Endpoint {
        if let envURL = environment[envURLKey]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !envURL.isEmpty {
            guard let url = URL(string: envURL), url.scheme != nil else {
                throw UpdaterError.invalidUpdateURL(envURL)
            }
            return .customManifest(url)
        }
        if let defaultsURL = defaults.string(forKey: updateURLKey)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !defaultsURL.isEmpty {
            guard let url = URL(string: defaultsURL), url.scheme != nil else {
                throw UpdaterError.invalidUpdateURL(defaultsURL)
            }
            return .customManifest(url)
        }
        if let plistURL = (infoDictionary?[infoPlistURLKey] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !plistURL.isEmpty, !plistURL.hasPrefix("@") {
            guard let url = URL(string: plistURL), url.scheme != nil else {
                throw UpdaterError.invalidUpdateURL(plistURL)
            }
            return .customManifest(url)
        }
        guard let url = URL(string: "https://api.github.com/repos/\(repo)/releases/latest") else {
            throw UpdaterError.invalidUpdateURL(repo)
        }
        return .githubLatestRelease(url)
    }

    // MARK: - Auto-check on Launch

    public static var isRunningInTestsOrCLI: Bool {
        let env = ProcessInfo.processInfo.environment
        if env["XCTestConfigurationFilePath"] != nil || env["XCTestBundlePath"] != nil || env["SWIFT_TESTING"] != nil {
            return true
        }
        if NSClassFromString("XCTestCase") != nil {
            return true
        }
        let args = CommandLine.arguments
        if args.contains("--snapshot") || args.contains("--help") || args.contains("--version") {
            return true
        }
        let execPath = args.first ?? ""
        if execPath.contains(".build/") || execPath.contains("/usr/bin/swift") || execPath.hasSuffix("xctest") {
            return env[envURLKey] == nil
        }
        return false
    }

    public func shouldAutoCheck(now: Date = Date()) -> Bool {
        guard autoCheckEnabled else { return false }
        if let last = lastCheckDate, now.timeIntervalSince(last) < Self.autoCheckInterval {
            return false
        }
        return true
    }

    public func checkForUpdatesOnLaunchIfNeeded() {
        guard !Self.isRunningInTestsOrCLI else { return }
        guard shouldAutoCheck() else { return }
        Task {
            await checkForUpdates(userInitiated: false)
        }
    }

    // MARK: - Checking for Updates

    public func checkForUpdates(userInitiated: Bool = true) async {
        if userInitiated {
            presentUpdateUI?()
        }
        state = .checking
        do {
            let endpoint = try Self.resolveEndpoint(repo: repo, defaults: defaults)
            let release = try await fetchRelease(from: endpoint)
            lastCheckDate = Date()
            let currentVersion = Self.currentVersionString
            let currentBuild = Self.currentBuildNumber
            if Self.isNewer(
                remoteVersion: release.version,
                remoteBuild: release.build,
                currentVersion: currentVersion,
                currentBuild: currentBuild
            ) {
                availableRelease = release
                state = .updateAvailable(release)
                if userInitiated {
                    presentUpdateUI?()
                }
            } else {
                availableRelease = nil
                state = .upToDate(currentVersion: currentVersion)
            }
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            state = .error(message)
        }
    }

    public func fetchRelease(from endpoint: Endpoint) async throws -> ReleaseInfo {
        var request = URLRequest(url: endpoint.url)
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("SimpleText/\(Self.currentVersionString)", forHTTPHeaderField: "User-Agent")
        if case .githubLatestRelease = endpoint {
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        } else {
            request.setValue("application/json", forHTTPHeaderField: "Accept")
        }

        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw UpdaterError.invalidHTTPStatus(http.statusCode)
        }

        switch endpoint {
        case .customManifest:
            return try Self.parseManifest(data, bundleIdentifier: bundleIdentifier)
        case .githubLatestRelease:
            return try Self.parseGitHubRelease(data)
        }
    }

    // MARK: - Manifest & GitHub Release Parsing

    /// Parses either a custom manifest (multi-app keyed by bundle ID or single-object) or a GitHub release object.
    public nonisolated static func parseManifest(_ data: Data, bundleIdentifier: String = defaultBundleID) throws -> ReleaseInfo {
        let rawObject: Any
        do {
            rawObject = try JSONSerialization.jsonObject(with: data, options: [])
        } catch {
            throw UpdaterError.malformedManifest(error.localizedDescription)
        }
        guard let dict = rawObject as? [String: Any] else {
            throw UpdaterError.malformedManifest("root is not a JSON object")
        }

        // If it looks like a GitHub release payload, delegate to parseGitHubRelease.
        if dict["tag_name"] != nil, dict["assets"] != nil {
            return try parseGitHubRelease(data)
        }

        // Multi-app manifest keyed by bundle identifier: {"net.cieadrienm.simpletext": { ... }}
        if let nested = dict[bundleIdentifier] as? [String: Any] {
            return try parseManifestEntry(nested)
        }
        if let apps = dict["apps"] as? [String: Any], let nested = apps[bundleIdentifier] as? [String: Any] {
            return try parseManifestEntry(nested)
        }

        // Single-object manifest: {"version": "...", "url": "...", ...}
        return try parseManifestEntry(dict)
    }

    private nonisolated static func parseManifestEntry(_ entry: [String: Any]) throws -> ReleaseInfo {
        guard let rawVersion = (entry["version"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawVersion.isEmpty else {
            throw UpdaterError.malformedManifest("missing 'version'")
        }
        let rawURL = (entry["url"] as? String)
            ?? (entry["download_url"] as? String)
            ?? (entry["downloadURL"] as? String)
        guard let urlString = rawURL?.trimmingCharacters(in: .whitespacesAndNewlines),
              !urlString.isEmpty,
              let downloadURL = URL(string: urlString) else {
            throw UpdaterError.malformedManifest("missing or invalid 'url'")
        }

        let build: Int?
        if let b = entry["build"] as? Int {
            build = b
        } else if let bStr = entry["build"] as? String, let b = Int(bStr.trimmingCharacters(in: .whitespacesAndNewlines)) {
            build = b
        } else {
            build = nil
        }

        let sha256 = (entry["sha256"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackNotes = entry["notes"] as? String
        let notesFR = (entry["notes_fr"] as? String) ?? fallbackNotes
        let notesEN = (entry["notes_en"] as? String) ?? fallbackNotes
        let htmlURL = ((entry["html_url"] as? String) ?? (entry["page_url"] as? String)).flatMap(URL.init(string:))
        let publishedAt = (entry["published_at"] as? String) ?? (entry["date"] as? String)

        return ReleaseInfo(
            version: rawVersion,
            build: build,
            downloadURL: downloadURL,
            sha256: sha256?.isEmpty == true ? nil : sha256,
            notesFR: notesFR,
            notesEN: notesEN,
            htmlURL: htmlURL,
            publishedAt: publishedAt
        )
    }

    /// Parses GitHub Releases API JSON (`/repos/<owner>/<repo>/releases/latest`).
    public nonisolated static func parseGitHubRelease(_ data: Data) throws -> ReleaseInfo {
        let rawObject: Any
        do {
            rawObject = try JSONSerialization.jsonObject(with: data, options: [])
        } catch {
            throw UpdaterError.malformedManifest(error.localizedDescription)
        }
        guard let dict = rawObject as? [String: Any] else {
            throw UpdaterError.malformedManifest("root is not a JSON object")
        }
        guard let tagName = (dict["tag_name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !tagName.isEmpty else {
            throw UpdaterError.malformedManifest("missing 'tag_name'")
        }
        let version = normalizeVersion(tagName)
        guard !version.isEmpty else {
            throw UpdaterError.malformedManifest("empty version in 'tag_name'")
        }

        guard let assets = dict["assets"] as? [[String: Any]] else {
            throw UpdaterError.noZipAssetFound
        }
        var chosenAsset: [String: Any]?
        for asset in assets {
            let name = (asset["name"] as? String)?.lowercased() ?? ""
            let urlStr = (asset["browser_download_url"] as? String)?.lowercased() ?? ""
            if name.hasSuffix(".zip") || urlStr.hasSuffix(".zip") {
                chosenAsset = asset
                break
            }
        }
        guard let asset = chosenAsset,
              let downloadStr = asset["browser_download_url"] as? String,
              let downloadURL = URL(string: downloadStr) else {
            throw UpdaterError.noZipAssetFound
        }

        let body = dict["body"] as? String
        var sha256: String?
        if let digest = asset["digest"] as? String, digest.lowercased().hasPrefix("sha256:") {
            sha256 = String(digest.dropFirst("sha256:".count))
        } else if let body {
            sha256 = extractSHA256(fromReleaseBody: body)
        }
        let htmlURL = (dict["html_url"] as? String).flatMap(URL.init(string:))
        let publishedAt = dict["published_at"] as? String

        return ReleaseInfo(
            version: version,
            build: nil,
            downloadURL: downloadURL,
            sha256: sha256,
            notesFR: body,
            notesEN: body,
            htmlURL: htmlURL,
            publishedAt: publishedAt
        )
    }

    private nonisolated static func extractSHA256(fromReleaseBody body: String) -> String? {
        // Matches e.g. "sha256: <64 hex chars>" or "SHA-256: `<64 hex chars>`"
        let pattern = #"(?i)sha-?256\s*[:=]\s*`?([0-9a-f]{64})`?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsRange = NSRange(body.startIndex..<body.endIndex, in: body)
        guard let match = regex.firstMatch(in: body, range: nsRange),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: body) else {
            return nil
        }
        return String(body[range]).lowercased()
    }

    // MARK: - Semantic Version Comparison

    public nonisolated static func normalizeVersion(_ raw: String) -> String {
        var trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        while trimmed.hasPrefix("v") || trimmed.hasPrefix("V") {
            trimmed.removeFirst()
        }
        return trimmed
    }

    public nonisolated static func compareVersions(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let leftParts = numericComponents(of: lhs)
        let rightParts = numericComponents(of: rhs)
        let count = max(leftParts.count, rightParts.count)
        for i in 0..<count {
            let l = i < leftParts.count ? leftParts[i] : 0
            let r = i < rightParts.count ? rightParts[i] : 0
            if l > r { return .orderedDescending }
            if l < r { return .orderedAscending }
        }
        return .orderedSame
    }

    public nonisolated static func isNewer(
        remoteVersion: String,
        remoteBuild: Int? = nil,
        currentVersion: String,
        currentBuild: Int? = nil
    ) -> Bool {
        let cmp = compareVersions(remoteVersion, currentVersion)
        if cmp == .orderedDescending { return true }
        if cmp == .orderedAscending { return false }
        if let remoteBuild, let currentBuild {
            return remoteBuild > currentBuild
        }
        return false
    }

    private nonisolated static func numericComponents(of version: String) -> [Int] {
        let clean = normalizeVersion(version)
        // Strip any pre-release/build suffix after '-' or '+'
        let core = clean.split(whereSeparator: { $0 == "-" || $0 == "+" }).first.map(String.init) ?? clean
        return core.split(separator: ".").map { Int($0) ?? 0 }
    }

    // MARK: - SHA-256 & Code Signature Verification

    public nonisolated static func sha256Hex(of data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    public nonisolated static func sha256Hex(ofFile url: URL) throws -> String {
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        return sha256Hex(of: data)
    }

    public nonisolated static func verifySHA256(fileURL: URL, expected: String?) throws {
        guard let expected = expected?.trimmingCharacters(in: .whitespacesAndNewlines),
              !expected.isEmpty else {
            return
        }
        let actual = try sha256Hex(ofFile: fileURL)
        if actual.lowercased() != expected.lowercased() {
            throw UpdaterError.checksumMismatch(expected: expected.lowercased(), actual: actual.lowercased())
        }
    }

    public nonisolated static func extractArchive(zipURL: URL, to destinationDirectory: URL) throws {
        try FileManager.default.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)
        let result = runProcess("/usr/bin/ditto", arguments: ["-x", "-k", zipURL.path, destinationDirectory.path])
        if result.exitCode != 0 {
            throw UpdaterError.extractionFailed(result.stderr.isEmpty ? "ditto exit \(result.exitCode)" : result.stderr)
        }
    }

    public nonisolated static func findAppBundle(in directory: URL) throws -> URL {
        let fm = FileManager.default
        if let contents = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]),
           let direct = contents.first(where: { $0.pathExtension.lowercased() == "app" }) {
            return direct
        }
        if let enumerator = fm.enumerator(at: directory, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) {
            for case let url as URL in enumerator where url.pathExtension.lowercased() == "app" {
                return url
            }
        }
        throw UpdaterError.appBundleNotFound
    }

    public nonisolated static func verifyCodeSignature(of appURL: URL, requiredTeamID: String? = currentTeamIdentifier()) throws {
        let verify = runProcess("/usr/bin/codesign", arguments: ["--verify", "--deep", "--strict", appURL.path])
        if verify.exitCode != 0 {
            let detail = verify.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            throw UpdaterError.invalidCodeSignature(detail.isEmpty ? "codesign exit \(verify.exitCode)" : detail)
        }
        if let requiredTeamID, !requiredTeamID.isEmpty {
            let actualTeam = teamIdentifier(of: appURL)
            if actualTeam != requiredTeamID {
                throw UpdaterError.teamIdentifierMismatch(expected: requiredTeamID, actual: actualTeam)
            }
        }
    }

    public nonisolated static func currentTeamIdentifier() -> String? {
        let url = Bundle.main.bundleURL
        guard url.pathExtension.lowercased() == "app" else { return nil }
        return teamIdentifier(of: url)
    }

    public nonisolated static func teamIdentifier(of appURL: URL) -> String? {
        let info = runProcess("/usr/bin/codesign", arguments: ["-dv", "--verbose=4", appURL.path])
        let combined = info.stderr + "\n" + info.stdout
        return parseTeamIdentifier(fromCodesignOutput: combined)
    }

    public nonisolated static func parseTeamIdentifier(fromCodesignOutput output: String) -> String? {
        for line in output.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("TeamIdentifier=") {
                let value = String(trimmed.dropFirst("TeamIdentifier=".count)).trimmingCharacters(in: .whitespaces)
                if value.isEmpty || value == "not set" {
                    return nil
                }
                return value
            }
        }
        return nil
    }

    public nonisolated static func replacementShellCommand(newAppPath: String, destinationAppPath: String) -> String {
        let escapedDest = destinationAppPath.replacingOccurrences(of: "\"", with: "\\\"")
        let escapedNew = newAppPath.replacingOccurrences(of: "\"", with: "\\\"")
        return "sleep 0.6; rm -rf \"\(escapedDest)\"; ditto \"\(escapedNew)\" \"\(escapedDest)\"; xattr -dr com.apple.quarantine \"\(escapedDest)\" 2>/dev/null || true; open \"\(escapedDest)\""
    }

    // MARK: - Download and Install

    public func downloadAndInstall(_ release: ReleaseInfo? = nil) async {
        guard let targetRelease = release ?? availableRelease else { return }
        state = .downloading(targetRelease)

        let stagingRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("SimpleTextUpdate-\(UUID().uuidString)", isDirectory: true)
        let zipURL = stagingRoot.appendingPathComponent("update.zip")
        let extractDir = stagingRoot.appendingPathComponent("extracted", isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: stagingRoot, withIntermediateDirectories: true)

            var request = URLRequest(url: targetRelease.downloadURL)
            request.timeoutInterval = 120
            request.setValue("SimpleText/\(Self.currentVersionString)", forHTTPHeaderField: "User-Agent")

            let (tempFileURL, response) = try await session.download(for: request)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                throw UpdaterError.invalidHTTPStatus(http.statusCode)
            }
            if FileManager.default.fileExists(atPath: zipURL.path) {
                try FileManager.default.removeItem(at: zipURL)
            }
            try FileManager.default.moveItem(at: tempFileURL, to: zipURL)

            state = .installing(targetRelease)

            try Self.verifySHA256(fileURL: zipURL, expected: targetRelease.sha256)
            try Self.extractArchive(zipURL: zipURL, to: extractDir)
            let newAppURL = try Self.findAppBundle(in: extractDir)
            try Self.verifyCodeSignature(of: newAppURL)

            let currentBundleURL = Bundle.main.bundleURL
            let destinationURL: URL
            if currentBundleURL.pathExtension.lowercased() == "app" {
                destinationURL = currentBundleURL
            } else {
                destinationURL = URL(fileURLWithPath: "/Applications/SimpleText.app")
            }

            let command = Self.replacementShellCommand(
                newAppPath: newAppURL.path,
                destinationAppPath: destinationURL.path
            )
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            process.arguments = ["-c", command]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try process.run()

            NSApp.terminate(nil)
        } catch {
            try? FileManager.default.removeItem(at: stagingRoot)
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            state = .error(message)
        }
    }

    // MARK: - Process Helper

    private struct ProcessOutput {
        let exitCode: Int32
        let stdout: String
        let stderr: String
    }

    private nonisolated static func runProcess(_ launchPath: String, arguments: [String]) -> ProcessOutput {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments
        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return ProcessOutput(exitCode: -1, stdout: "", stderr: error.localizedDescription)
        }
        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        return ProcessOutput(
            exitCode: process.terminationStatus,
            stdout: String(data: outData, encoding: .utf8) ?? "",
            stderr: String(data: errData, encoding: .utf8) ?? ""
        )
    }
}
