import Foundation
import Testing
@testable import SimpleTextCore

/// The kind of the first token whose text is `word`, in `source` lexed as `language`.
private func kind(of word: String, in source: String, _ language: String) -> TokenKind? {
    let lexer = Lexers.lexer(for: Language.named(language)!)!
    let tokens = Tokenizer.tokenize(source, with: lexer)
    let units = Array(source.utf16)
    for token in tokens {
        let text = String(utf16CodeUnits: Array(units[token.range]), count: token.range.count)
        if text == word { return token.kind }
    }
    return nil
}

@Suite("Lexers")
struct LexerTests {
    @Test("Swift: keywords, types, attributes, strings with interpolation, nested comments")
    func swift() {
        let source = """
        import AVFoundation
        /// Plays a clip. /* nested /* deeper */ still */
        @MainActor final class Player: NSObject {
            private let engine = AVAudioEngine()
            var gain: Float = 0.5
            func play(url: URL) throws {
                print("playing \\(url.lastPathComponent) frames")
                let raw = #"a "quoted" word"#
                #if DEBUG
                #endif
            }
        }
        """
        #expect(kind(of: "import", in: source, "Swift") == .keyword)
        #expect(kind(of: "AVFoundation", in: source, "Swift") == .type)
        #expect(kind(of: "/// Plays a clip. /* nested /* deeper */ still */", in: source, "Swift") == .comment)
        #expect(kind(of: "@MainActor", in: source, "Swift") == .attribute)
        #expect(kind(of: "final", in: source, "Swift") == .keyword)
        #expect(kind(of: "Player", in: source, "Swift") == .type)
        #expect(kind(of: "AVAudioEngine", in: source, "Swift") == .type)
        #expect(kind(of: "Float", in: source, "Swift") == .type)
        #expect(kind(of: "0.5", in: source, "Swift") == .number)
        #expect(kind(of: "print", in: source, "Swift") == .function)
        #expect(kind(of: "\"playing \\(url.lastPathComponent) frames\"", in: source, "Swift") == .string)
        #expect(kind(of: "#\"a \"quoted\" word\"#", in: source, "Swift") == .string)
        #expect(kind(of: "#if DEBUG", in: source, "Swift") == .preprocessor)
    }

    @Test("A Swift multi-line string carries its state across lines")
    func swiftMultilineString() {
        let source = "let s = \"\"\"\nlet x = 1\n\"\"\"\nlet y = 2"
        let lexer = Lexers.lexer(for: Language.named("Swift")!)!
        let tokens = Tokenizer.tokenize(source, with: lexer)
        let units = Array(source.utf16)
        let inside = tokens.first { String(utf16CodeUnits: Array(units[$0.range]), count: $0.range.count) == "let x = 1" }
        #expect(inside?.kind == .string)
        #expect(kind(of: "y", in: source, "Swift") == .plain)
    }

    @Test("Objective-C: directives, message strings, nil, class names")
    func objectiveC() {
        let source = """
        #import <Foundation/Foundation.h>
        @interface Shape : NSObject
        @property (nonatomic, assign) CGFloat radius;
        - (instancetype)initWithRadius:(CGFloat)radius;
        @end
        NSString *name = @"disque"; // nom
        if (name == nil) { return NO; }
        """
        #expect(kind(of: "#import <Foundation/Foundation.h>", in: source, "Objective-C") == .preprocessor)
        #expect(kind(of: "@interface", in: source, "Objective-C") == .keyword)
        #expect(kind(of: "NSObject", in: source, "Objective-C") == .type)
        #expect(kind(of: "nonatomic", in: source, "Objective-C") == .keyword)
        #expect(kind(of: "CGFloat", in: source, "Objective-C") == .type)
        #expect(kind(of: "@\"disque\"", in: source, "Objective-C") == .string)
        #expect(kind(of: "// nom", in: source, "Objective-C") == .comment)
        #expect(kind(of: "nil", in: source, "Objective-C") == .constant)
        #expect(kind(of: "NO", in: source, "Objective-C") == .constant)
    }

    @Test("C: preprocessor, types, char literal, block comment over two lines")
    func c() {
        let source = "#include <stdio.h>\n/* start\nend */ int main(void) { char c = 'x'; return 0; }"
        #expect(kind(of: "#include <stdio.h>", in: source, "C") == .preprocessor)
        #expect(kind(of: "/* start", in: source, "C") == .comment)
        #expect(kind(of: "end */", in: source, "C") == .comment)
        #expect(kind(of: "int", in: source, "C") == .type)
        #expect(kind(of: "main", in: source, "C") == .function)
        #expect(kind(of: "'x'", in: source, "C") == .string)
        #expect(kind(of: "return", in: source, "C") == .keyword)
    }

    @Test("C#: verbatim strings, attributes, generics")
    func csharp() {
        let source = """
        using System;
        [Serializable] public class Player : MonoBehaviour {
            string path = @"C:\\temp\\x";
            void Start() { Debug.Log($"gain {gain}"); var list = new List<int>(); }
        }
        """
        #expect(kind(of: "using", in: source, "C#") == .keyword)
        #expect(kind(of: "MonoBehaviour", in: source, "C#") == .type)
        #expect(kind(of: "string", in: source, "C#") == .type)
        #expect(kind(of: "@\"C:\\temp\\x\"", in: source, "C#") == .string)
        #expect(kind(of: "$\"gain {gain}\"", in: source, "C#") == .string)
        #expect(kind(of: "Log", in: source, "C#") == .function)
        #expect(kind(of: "new", in: source, "C#") == .keyword)
    }

    @Test("HTML: tags, attributes, entities, comments, embedded script and PHP")
    func html() {
        let source = """
        <!DOCTYPE html>
        <html lang="fr"><!-- un commentaire -->
        <body class="dark" data-x=1>&eacute;<script>let a = 1;</script>
        <?php echo $title; ?>
        <style>.a { color: red; }</style>
        </body></html>
        """
        #expect(kind(of: "<!DOCTYPE html>", in: source, "HTML") == .meta)
        #expect(kind(of: "<html", in: source, "HTML") == .tag)
        #expect(kind(of: "lang", in: source, "HTML") == .attributeName)
        #expect(kind(of: "\"fr\"", in: source, "HTML") == .string)
        #expect(kind(of: "<!-- un commentaire -->", in: source, "HTML") == .comment)
        #expect(kind(of: "&eacute;", in: source, "HTML") == .escape)
        #expect(kind(of: "let", in: source, "HTML") == .keyword)
        #expect(kind(of: "<?php", in: source, "HTML") == .meta)
        #expect(kind(of: "echo", in: source, "HTML") == .keyword)
        #expect(kind(of: "$title", in: source, "HTML") == .variable)
        #expect(kind(of: "color", in: source, "HTML") == .property)
        #expect(kind(of: "</body", in: source, "HTML") == .tag)
    }

    @Test("PHP: a file starts in HTML; variables, keywords, strings, comments inside the block")
    func php() {
        let source = """
        <h1><?php
        $items = ['a' => 1];
        foreach ($items as $key => $value) { // boucle
            echo "<li>$key</li>\\n";
        }
        ?></h1>
        """
        #expect(kind(of: "<h1", in: source, "PHP") == .tag)
        #expect(kind(of: "$items", in: source, "PHP") == .variable)
        #expect(kind(of: "'a'", in: source, "PHP") == .string)
        #expect(kind(of: "foreach", in: source, "PHP") == .keyword)
        #expect(kind(of: "// boucle", in: source, "PHP") == .comment)
        #expect(kind(of: "\"<li>$key</li>\\n\"", in: source, "PHP") == .string)
        #expect(kind(of: "?>", in: source, "PHP") == .meta)
    }

    @Test("Markdown: headings, lists, emphasis, code spans, links, fenced Swift code")
    func markdown() {
        let source = """
        # Titre
        - un *mot* en **gras** et `code`
        1. [lien](http://x.y) ![img](a.png)
        > citation
        ```swift
        let n = 1
        ```
        ---
        """
        #expect(kind(of: "# Titre", in: source, "Markdown") == .heading)
        #expect(kind(of: "-", in: source, "Markdown") == .listMarker)
        #expect(kind(of: "*mot*", in: source, "Markdown") == .emphasis)
        #expect(kind(of: "**gras**", in: source, "Markdown") == .strong)
        #expect(kind(of: "`code`", in: source, "Markdown") == .codeSpan)
        #expect(kind(of: "1.", in: source, "Markdown") == .listMarker)
        #expect(kind(of: "[lien]", in: source, "Markdown") == .link)
        #expect(kind(of: "(http://x.y)", in: source, "Markdown") == .meta)
        #expect(kind(of: "> citation", in: source, "Markdown") == .quote)
        #expect(kind(of: "swift", in: source, "Markdown") == .attribute)
        #expect(kind(of: "let", in: source, "Markdown") == .keyword)
        #expect(kind(of: "1", in: source, "Markdown") == .number)
        #expect(kind(of: "---", in: source, "Markdown") == .meta)
    }

    @Test("JavaScript, TypeScript, JSON, CSS, Python, Shell, YAML")
    func commonLanguages() {
        #expect(kind(of: "const", in: "const f = async () => `t ${x}`;", "JavaScript") == .keyword)
        #expect(kind(of: "`t ${x}`", in: "const f = async () => `t ${x}`;", "JavaScript") == .string)
        #expect(kind(of: "interface", in: "interface A { n: number }", "TypeScript") == .keyword)
        #expect(kind(of: "number", in: "interface A { n: number }", "TypeScript") == .type)
        #expect(kind(of: "\"name\"", in: "{ \"name\": \"x\", \"on\": true }", "JSON") == .property)
        #expect(kind(of: "\"x\"", in: "{ \"name\": \"x\", \"on\": true }", "JSON") == .string)
        #expect(kind(of: "true", in: "{ \"name\": \"x\", \"on\": true }", "JSON") == .constant)
        let css = ".card:hover { color: #fff; margin: 12px 0; } @media (max-width: 600px) { p { font-size: 1.2em } }"
        #expect(kind(of: ".card", in: css, "CSS") == .type)
        #expect(kind(of: ":hover", in: css, "CSS") == .attributeName)
        #expect(kind(of: "color", in: css, "CSS") == .property)
        #expect(kind(of: "#fff", in: css, "CSS") == .number)
        #expect(kind(of: "12px", in: css, "CSS") == .number)
        #expect(kind(of: "@media", in: css, "CSS") == .keyword)
        #expect(kind(of: "def", in: "@app.route\ndef f(x): # c\n    return None", "Python") == .keyword)
        #expect(kind(of: "@app", in: "@app.route\ndef f(x): # c\n    return None", "Python") == .attribute)
        #expect(kind(of: "None", in: "@app.route\ndef f(x): # c\n    return None", "Python") == .constant)
        #expect(kind(of: "$HOME", in: "if [ -d \"$HOME\" ]; then echo ok; fi # c", "Shell") == nil)
        #expect(kind(of: "\"$HOME\"", in: "if [ -d \"$HOME\" ]; then echo ok; fi # c", "Shell") == .string)
        #expect(kind(of: "then", in: "if [ -d \"$HOME\" ]; then echo ok; fi # c", "Shell") == .keyword)
        #expect(kind(of: "# c", in: "if [ -d \"$HOME\" ]; then echo ok; fi # c", "Shell") == .comment)
        #expect(kind(of: "name", in: "name: SimpleText\nlist:\n  - 3\n  - yes # ok", "YAML") == .property)
        #expect(kind(of: "3", in: "name: SimpleText\nlist:\n  - 3\n  - yes # ok", "YAML") == .number)
        #expect(kind(of: "yes", in: "name: SimpleText\nlist:\n  - 3\n  - yes # ok", "YAML") == .constant)
        #expect(kind(of: "# ok", in: "name: SimpleText\nlist:\n  - 3\n  - yes # ok", "YAML") == .comment)
    }

    @Test("Rust lifetimes are not char literals; Makefile targets and variables")
    func edgeCases() {
        let rust = "fn f<'a>(x: &'a str) -> char { 'x' }"
        #expect(kind(of: "'x'", in: rust, "Rust") == .string)
        #expect(kind(of: "str", in: rust, "Rust") == .type)
        #expect(kind(of: "'a", in: rust, "Rust") == nil)
        let make = "CC = gcc\nall: main.o # build\n\t$(CC) -o app $(OBJS)"
        #expect(kind(of: "all", in: make, "Makefile") == .function)
        #expect(kind(of: "$(CC)", in: make, "Makefile") == .variable)
        #expect(kind(of: "# build", in: make, "Makefile") == .comment)
        #expect(kind(of: "+ added", in: "--- a\n+++ b\n@@ -1 +1 @@\n+ added\n- gone", "Diff") == .inserted)
        #expect(kind(of: "- gone", in: "--- a\n+++ b\n@@ -1 +1 @@\n+ added\n- gone", "Diff") == .deleted)
        #expect(kind(of: "[server]", in: "[server]\nport = 8080 # c\nname = \"x\"", "TOML") == .tag)
        #expect(kind(of: "port", in: "[server]\nport = 8080 # c\nname = \"x\"", "TOML") == .property)
        #expect(kind(of: "8080", in: "[server]\nport = 8080 # c\nname = \"x\"", "TOML") == .number)
    }

    @Test("Re-lexing from a stored state gives the same tokens as lexing from the start")
    func stateIsSelfContained() {
        let source = "a = \"\"\"\nb\n\"\"\"\n/* c\nd */ e"
        let lexer = Lexers.lexer(for: Language.named("Swift")!)!
        let units = Array(source.utf16)
        let lines = source.split(separator: "\n", omittingEmptySubsequences: false)
        var state = LexState.initial
        var offset = 0
        var states: [LexState] = []
        for line in lines {
            states.append(state)
            let count = line.utf16.count
            _ = lexer.tokenize(units[offset..<offset + count], state: &state)
            offset += count + 1
        }
        // Lexing the third line (the closing """ at offsets 10..<13) again from its stored state closes
        // the string, as the first pass did.
        var again = states[2]
        let tokens = lexer.tokenize(units[10..<13], state: &again)
        #expect(tokens.first?.kind == .string)
        #expect(again == states[3])
    }
}
