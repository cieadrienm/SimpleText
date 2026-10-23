import Foundation

/// A language the editor knows: how to recognise its files and how it writes comments.
/// Highlighting rules come with the lexers; a language without rules is shown as plain text.
public struct Language: Equatable, Identifiable, Sendable {
    public struct BlockComment: Equatable, Sendable {
        public let open: String
        public let close: String
        public init(_ open: String, _ close: String) {
            self.open = open
            self.close = close
        }
    }

    public let name: String
    public let extensions: [String]
    public let filenames: [String]
    public let lineComment: String?
    public let blockComment: BlockComment?

    public var id: String { name }

    public init(
        _ name: String,
        extensions: [String],
        filenames: [String] = [],
        lineComment: String? = nil,
        blockComment: BlockComment? = nil
    ) {
        self.name = name
        self.extensions = extensions
        self.filenames = filenames
        self.lineComment = lineComment
        self.blockComment = blockComment
    }

    public static let plainText = Language("Texte brut", extensions: ["txt", "text", "log", "csv", "tsv"])

    private static let cBlock = BlockComment("/*", "*/")
    private static let htmlBlock = BlockComment("<!--", "-->")

    /// Every language, in the order of the status bar menu.
    public static let all: [Language] = [
        plainText,
        Language("C", extensions: ["c", "i"], lineComment: "//", blockComment: cBlock),
        Language("Objective-C", extensions: ["m", "h"], lineComment: "//", blockComment: cBlock),
        Language("Objective-C++", extensions: ["mm"], lineComment: "//", blockComment: cBlock),
        Language("C++", extensions: ["cpp", "cc", "cxx", "hpp", "hh", "hxx", "h++", "ino", "ipp"], lineComment: "//", blockComment: cBlock),
        Language("C#", extensions: ["cs", "csx"], lineComment: "//", blockComment: cBlock),
        Language("Swift", extensions: ["swift"], lineComment: "//", blockComment: cBlock),
        Language("Metal", extensions: ["metal"], lineComment: "//", blockComment: cBlock),
        Language("GLSL", extensions: ["glsl", "vert", "frag", "geom", "comp", "vs", "fs"], lineComment: "//", blockComment: cBlock),
        Language("Java", extensions: ["java"], lineComment: "//", blockComment: cBlock),
        Language("Kotlin", extensions: ["kt", "kts"], lineComment: "//", blockComment: cBlock),
        Language("JavaScript", extensions: ["js", "mjs", "cjs", "jsx"], lineComment: "//", blockComment: cBlock),
        Language("TypeScript", extensions: ["ts", "tsx", "mts", "cts"], lineComment: "//", blockComment: cBlock),
        Language("JSON", extensions: ["json", "jsonc", "map", "webmanifest", "geojson"], lineComment: "//", blockComment: cBlock),
        Language("HTML", extensions: ["html", "htm", "xhtml", "shtml"], blockComment: htmlBlock),
        Language("PHP", extensions: ["php", "phtml", "php3", "php4", "php5", "php7", "phps"], lineComment: "//", blockComment: cBlock),
        Language("CSS", extensions: ["css"], blockComment: cBlock),
        Language("SCSS", extensions: ["scss", "sass", "less"], lineComment: "//", blockComment: cBlock),
        Language("Markdown", extensions: ["md", "markdown", "mdown", "mkd", "mkdn", "mdx"], blockComment: htmlBlock),
        Language("Python", extensions: ["py", "pyw", "pyi"], lineComment: "#"),
        Language("Shell", extensions: ["sh", "bash", "zsh", "command", "ksh"], filenames: [".zshrc", ".bashrc", ".bash_profile", ".zprofile", ".profile"], lineComment: "#"),
        Language("YAML", extensions: ["yml", "yaml"], lineComment: "#"),
        Language("XML", extensions: ["xml", "plist", "svg", "xsl", "xsd", "xib", "storyboard", "entitlements", "xcscheme", "nib"], blockComment: htmlBlock),
        Language("TOML", extensions: ["toml"], lineComment: "#"),
        Language("INI", extensions: ["ini", "cfg", "conf", "properties", "gitconfig"], filenames: [".gitconfig", ".editorconfig"], lineComment: "#"),
        Language("SQL", extensions: ["sql"], lineComment: "--", blockComment: cBlock),
        Language("Go", extensions: ["go"], lineComment: "//", blockComment: cBlock),
        Language("Rust", extensions: ["rs"], lineComment: "//", blockComment: cBlock),
        Language("Ruby", extensions: ["rb", "rake", "gemspec"], filenames: ["Gemfile", "Rakefile"], lineComment: "#"),
        Language("Lua", extensions: ["lua"], lineComment: "--", blockComment: BlockComment("--[[", "]]")),
        Language("Perl", extensions: ["pl", "pm"], lineComment: "#"),
        Language("Makefile", extensions: ["mk", "mak"], filenames: ["Makefile", "makefile", "GNUmakefile"], lineComment: "#"),
        Language("Dockerfile", extensions: ["dockerfile"], filenames: ["Dockerfile", "Containerfile"], lineComment: "#"),
        Language("Diff", extensions: ["diff", "patch"]),
    ]

    public static func named(_ name: String) -> Language? {
        all.first { $0.name == name }
    }

    /// The language a file name points at; plain text when nothing matches.
    /// `.h` is Objective-C on purpose (DECISIONS.md): its rules cover C, and Adrien's headers are Objective-C.
    public static func forFile(named filename: String) -> Language {
        let name = (filename as NSString).lastPathComponent
        if let byName = all.first(where: { $0.filenames.contains(name) }) { return byName }
        let ext = (name as NSString).pathExtension.lowercased()
        guard !ext.isEmpty else { return plainText }
        return all.first { $0.extensions.contains(ext) } ?? plainText
    }
}
