import AppKit

/// The version stamped into the bundle by `Scripts/bundle.sh`; "dev" when run from `swift run` or the tests.
enum AppVersion {
    /// The icon from the bundle, or from the repository when run with `swift run` or the tests.
    static let icon: NSImage = {
        if Bundle.main.object(forInfoDictionaryKey: "CFBundleIconFile") != nil { return NSApp.applicationIconImage }
        let repository = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return NSImage(contentsOf: repository.appendingPathComponent("Resources/icon.png")) ?? NSApp.applicationIconImage
    }()

    static let name = "SimpleText"
    static let bundleIdentifier = "net.cieadrienm.simpletext"

    static var short: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        guard let version, !version.isEmpty, !version.hasPrefix("@") else { return "dev" }
        return version
    }

    static var build: String? {
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        guard let build, !build.isEmpty, !build.hasPrefix("@") else { return nil }
        return build
    }

    /// "v0.9.0" in a bundle, "dev" otherwise.
    static var shortLabel: String { short == "dev" ? "dev" : "v\(short)" }

    /// "SimpleText 0.9.0 (42)" for the clipboard and bug reports.
    static var description: String {
        if let build { return "\(name) \(short) (\(build))" }
        return "\(name) \(short)"
    }
}
