import Foundation

/// The lexer of each language, and the names Markdown fences use for them.
public enum Lexers {
    private static let table: [String: any Lexer] = [
        "C": GenericLexer(Syntaxes.c),
        "Objective-C": GenericLexer(Syntaxes.objectiveC),
        "Objective-C++": GenericLexer(Syntaxes.objectiveCpp),
        "C++": GenericLexer(Syntaxes.cpp),
        "C#": GenericLexer(Syntaxes.csharp),
        "Swift": GenericLexer(Syntaxes.swift),
        "Metal": GenericLexer(Syntaxes.shader),
        "GLSL": GenericLexer(Syntaxes.shader),
        "Java": GenericLexer(Syntaxes.java),
        "Kotlin": GenericLexer(Syntaxes.kotlin),
        "JavaScript": GenericLexer(Syntaxes.javascript),
        "TypeScript": GenericLexer(Syntaxes.typescript),
        "JSON": GenericLexer(Syntaxes.json),
        "HTML": HTMLLexer(allowsPHP: true),
        "PHP": HTMLLexer(allowsPHP: true),
        "CSS": CSSLexer(scss: false),
        "SCSS": CSSLexer(scss: true),
        "Markdown": MarkdownLexer(),
        "Python": GenericLexer(Syntaxes.python),
        "Shell": GenericLexer(Syntaxes.shell),
        "YAML": YAMLLexer(),
        "XML": HTMLLexer(allowsPHP: false),
        "TOML": ConfigLexer(),
        "INI": ConfigLexer(),
        "SQL": GenericLexer(Syntaxes.sql),
        "Go": GenericLexer(Syntaxes.go),
        "Rust": GenericLexer(Syntaxes.rust),
        "Ruby": GenericLexer(Syntaxes.ruby),
        "Lua": GenericLexer(Syntaxes.lua),
        "Perl": GenericLexer(Syntaxes.perl),
        "Makefile": GenericLexer(Syntaxes.makefile),
        "Dockerfile": GenericLexer(Syntaxes.dockerfile),
        "Diff": DiffLexer(),
    ]

    /// Fence names that are neither a language name nor one of its extensions.
    private static let fenceAliases: [String: String] = [
        "objc": "Objective-C", "objective-c": "Objective-C", "objectivec": "Objective-C", "obj-c": "Objective-C",
        "c++": "C++", "cplusplus": "C++", "csharp": "C#", "c#": "C#", "javascript": "JavaScript",
        "typescript": "TypeScript", "shell": "Shell", "bash": "Shell", "zsh": "Shell", "console": "Shell",
        "python": "Python", "ruby": "Ruby", "rust": "Rust", "golang": "Go", "markdown": "Markdown",
        "make": "Makefile", "docker": "Dockerfile", "yaml": "YAML", "html": "HTML", "xml": "XML",
        "plist": "XML", "swift": "Swift", "metal": "Metal", "glsl": "GLSL", "sql": "SQL", "php": "PHP",
        "css": "CSS", "scss": "SCSS", "json": "JSON", "toml": "TOML", "ini": "INI", "lua": "Lua",
        "java": "Java", "kotlin": "Kotlin", "perl": "Perl", "diff": "Diff", "patch": "Diff", "c": "C",
    ]

    public static func lexer(for language: Language) -> (any Lexer)? {
        table[language.name]
    }

    /// Position in `Language.all`, so a lexer state can carry a language in a 16-bit field.
    public static func languageIndex(_ language: Language) -> UInt16? {
        Language.all.firstIndex(of: language).map { UInt16($0) }
    }

    public static func language(at index: UInt16) -> Language? {
        let i = Int(index)
        return i < Language.all.count ? Language.all[i] : nil
    }

    public static func languageIndex(forFence name: String) -> UInt16? {
        let key = name.lowercased()
        let language = fenceAliases[key].flatMap(Language.named)
            ?? Language.all.first { $0.name.lowercased() == key }
            ?? Language.all.first { $0.extensions.contains(key) }
        return language.flatMap(languageIndex)
    }
}

/// Tokenizes a whole text, line by line, carrying the state. The app does the same incrementally.
public enum Tokenizer {
    public static func tokenize(_ text: String, with lexer: any Lexer) -> [Token] {
        let units = Array(text.utf16)
        var tokens: [Token] = []
        var state = LexState.initial
        var lineStart = 0
        for (index, unit) in units.enumerated() where unit == 10 {
            tokens += lexer.tokenize(units[lineStart..<index], state: &state)
            lineStart = index + 1
        }
        tokens += lexer.tokenize(units[lineStart..<units.count], state: &state)
        return tokens
    }
}
