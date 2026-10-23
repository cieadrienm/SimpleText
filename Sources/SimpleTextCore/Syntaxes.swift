import Foundation

/// The rules of every table-driven language, one static per language, built on first use.
enum Syntaxes {
    private static let cKeywords: Set<String> = [
        "auto", "break", "case", "const", "continue", "default", "do", "else", "enum", "extern", "for", "goto", "if",
        "inline", "register", "restrict", "return", "sizeof", "static", "struct", "switch", "typedef", "union",
        "volatile", "while", "_Bool", "_Complex", "_Imaginary", "_Atomic", "_Static_assert", "_Thread_local",
    ]
    private static let cTypes: Set<String> = [
        "void", "char", "short", "int", "long", "float", "double", "signed", "unsigned", "bool", "size_t", "ssize_t",
        "int8_t", "int16_t", "int32_t", "int64_t", "uint8_t", "uint16_t", "uint32_t", "uint64_t", "intptr_t", "uintptr_t",
        "ptrdiff_t", "wchar_t", "FILE", "va_list",
    ]
    private static let cConstants: Set<String> = ["NULL", "true", "false", "EOF"]
    private static let cStrings = [
        StringRule("\"", "\""),
        StringRule("'", "'", maxLength: 8),
    ]

    static let c = Syntax(
        lineComments: ["//"], blockComment: ("/*", "*/"), strings: cStrings,
        keywords: cKeywords, types: cTypes, constants: cConstants, preprocessor: true
    )

    private static let cppKeywords: Set<String> = cKeywords.union([
        "class", "namespace", "template", "typename", "public", "private", "protected", "virtual", "override", "final",
        "new", "delete", "this", "try", "catch", "throw", "using", "constexpr", "consteval", "constinit", "decltype",
        "static_cast", "dynamic_cast", "reinterpret_cast", "const_cast", "operator", "friend", "explicit", "mutable",
        "noexcept", "concept", "requires", "co_await", "co_return", "co_yield", "export", "module", "import",
        "typeid", "alignas", "alignof", "static_assert", "thread_local", "and", "or", "not",
    ])

    static let cpp = Syntax(
        lineComments: ["//"], blockComment: ("/*", "*/"),
        strings: cStrings + [StringRule("R\"(", ")\"", escape: nil, multiline: true)],
        keywords: cppKeywords, types: cTypes.union(["auto", "string", "wstring", "nullptr_t"]),
        constants: cConstants.union(["nullptr", "this"]), preprocessor: true, capitalizedTypes: true
    )

    private static let objcKeywords: Set<String> = cKeywords.union([
        "in", "out", "inout", "bycopy", "byref", "oneway", "self", "super", "instancetype", "nonatomic", "atomic",
        "strong", "weak", "copy", "assign", "retain", "readonly", "readwrite", "nullable", "nonnull", "null_resettable",
        "__block", "__weak", "__strong", "__unsafe_unretained", "__bridge", "__kindof", "IBOutlet", "IBAction",
    ])
    private static let objcTypes: Set<String> = cTypes.union(["id", "Class", "SEL", "IMP", "BOOL", "NSInteger", "NSUInteger", "CGFloat"])
    private static let objcConstants: Set<String> = cConstants.union(["nil", "Nil", "YES", "NO", "self", "super"])
    private static let objcStrings = cStrings + [StringRule("@\"", "\"")]

    static let objectiveC = Syntax(
        lineComments: ["//"], blockComment: ("/*", "*/"), strings: objcStrings,
        keywords: objcKeywords, types: objcTypes, constants: objcConstants, preprocessor: true,
        annotation: ("@", .keyword), capitalizedTypes: true
    )

    static let objectiveCpp = Syntax(
        lineComments: ["//"], blockComment: ("/*", "*/"), strings: objcStrings,
        keywords: objcKeywords.union(cppKeywords), types: objcTypes.union(["auto", "string"]),
        constants: objcConstants.union(["nullptr", "this"]), preprocessor: true,
        annotation: ("@", .keyword), capitalizedTypes: true
    )

    static let csharp = Syntax(
        lineComments: ["//"], blockComment: ("/*", "*/"),
        strings: [
            StringRule("\"", "\""), StringRule("'", "'", maxLength: 8),
            StringRule("@\"", "\"", escape: nil, multiline: true, doubledClose: true),
            StringRule("$\"", "\""), StringRule("$@\"", "\"", escape: nil, multiline: true, doubledClose: true),
            StringRule("@$\"", "\"", escape: nil, multiline: true, doubledClose: true),
            StringRule("\"\"\"", "\"\"\"", escape: nil, multiline: true),
        ],
        keywords: [
            "abstract", "as", "base", "break", "case", "catch", "checked", "class", "const", "continue", "default",
            "delegate", "do", "else", "enum", "event", "explicit", "extern", "finally", "fixed", "for", "foreach",
            "goto", "if", "implicit", "in", "interface", "internal", "is", "lock", "namespace", "new", "operator",
            "out", "override", "params", "private", "protected", "public", "readonly", "ref", "return", "sealed",
            "sizeof", "stackalloc", "static", "struct", "switch", "throw", "try", "typeof", "unchecked", "unsafe",
            "using", "virtual", "volatile", "while", "async", "await", "get", "set", "value", "yield", "partial",
            "record", "init", "nameof", "when", "where", "select", "from", "let", "group", "into", "orderby", "join",
            "equals", "var", "add", "remove", "global", "required", "file", "with", "and", "or", "not",
        ],
        types: [
            "bool", "byte", "char", "decimal", "double", "float", "int", "long", "object", "sbyte", "short", "string",
            "uint", "ulong", "ushort", "void", "dynamic", "nint", "nuint",
        ],
        constants: ["true", "false", "null", "this", "base"], preprocessor: true, capitalizedTypes: true
    )

    static let swift = Syntax(
        lineComments: ["//"], blockComment: ("/*", "*/"), nestedBlockComments: true,
        strings: [
            StringRule("\"\"\"", "\"\"\"", multiline: true), StringRule("\"", "\""),
            StringRule("#\"", "\"#", escape: nil), StringRule("#\"\"\"", "\"\"\"#", escape: nil, multiline: true),
        ],
        keywords: [
            "associatedtype", "class", "deinit", "enum", "extension", "fileprivate", "func", "import", "init", "inout",
            "internal", "let", "open", "operator", "private", "precedencegroup", "protocol", "public", "rethrows",
            "static", "struct", "subscript", "typealias", "var", "break", "case", "catch", "continue", "default",
            "defer", "do", "else", "fallthrough", "for", "guard", "if", "in", "repeat", "return", "throw", "switch",
            "where", "while", "as", "any", "await", "async", "is", "throws", "try", "some", "actor", "nonisolated",
            "isolated", "consuming", "borrowing", "lazy", "weak", "unowned", "mutating", "nonmutating", "override",
            "required", "convenience", "final", "dynamic", "indirect", "infix", "prefix", "postfix", "optional",
            "macro", "package", "each", "sending",
        ],
        types: ["Int", "Double", "Float", "String", "Bool", "Character", "Array", "Dictionary", "Set", "Optional", "Any", "AnyObject", "Void", "Never", "Error", "Result"],
        constants: ["true", "false", "nil", "self", "Self", "super"],
        preprocessor: true, annotation: ("@", .attribute), capitalizedTypes: true
    )

    private static let shaderKeywords: Set<String> = cKeywords.union([
        "kernel", "vertex", "fragment", "constant", "device", "threadgroup", "thread", "uniform", "varying",
        "attribute", "layout", "in", "out", "inout", "precision", "highp", "mediump", "lowp", "discard", "using",
        "namespace", "template", "typename", "class", "public", "private", "sampler", "texture", "buffer",
    ])
    private static let shaderTypes: Set<String> = cTypes.union([
        "half", "float2", "float3", "float4", "half2", "half3", "half4", "int2", "int3", "int4", "uint2", "uint3", "uint4",
        "float2x2", "float3x3", "float4x4", "vec2", "vec3", "vec4", "ivec2", "ivec3", "ivec4", "uvec2", "uvec3", "uvec4",
        "bvec2", "bvec3", "bvec4", "mat2", "mat3", "mat4", "sampler2D", "samplerCube", "texture2d", "texture3d",
        "texturecube", "depth2d", "uchar", "ushort", "uint",
    ])

    static let shader = Syntax(
        lineComments: ["//"], blockComment: ("/*", "*/"), strings: cStrings,
        keywords: shaderKeywords, types: shaderTypes, constants: cConstants, preprocessor: true
    )

    static let java = Syntax(
        lineComments: ["//"], blockComment: ("/*", "*/"),
        strings: [StringRule("\"\"\"", "\"\"\"", multiline: true), StringRule("\"", "\""), StringRule("'", "'", maxLength: 8)],
        keywords: [
            "abstract", "assert", "break", "case", "catch", "class", "const", "continue", "default", "do", "else",
            "enum", "extends", "final", "finally", "for", "goto", "if", "implements", "import", "instanceof",
            "interface", "native", "new", "package", "private", "protected", "public", "return", "static",
            "strictfp", "super", "switch", "synchronized", "this", "throw", "throws", "transient", "try", "var",
            "volatile", "while", "record", "sealed", "permits", "yield",
        ],
        types: ["boolean", "byte", "char", "double", "float", "int", "long", "short", "void", "String"],
        constants: ["true", "false", "null", "this", "super"], annotation: ("@", .attribute), capitalizedTypes: true
    )

    static let kotlin = Syntax(
        lineComments: ["//"], blockComment: ("/*", "*/"), nestedBlockComments: true,
        strings: [StringRule("\"\"\"", "\"\"\"", escape: nil, multiline: true), StringRule("\"", "\""), StringRule("'", "'", maxLength: 8)],
        keywords: [
            "as", "break", "class", "continue", "do", "else", "false", "for", "fun", "if", "in", "interface", "is",
            "null", "object", "package", "return", "super", "this", "throw", "true", "try", "typealias", "typeof",
            "val", "var", "when", "while", "by", "catch", "constructor", "delegate", "dynamic", "field", "file",
            "finally", "get", "import", "init", "param", "property", "receiver", "set", "setparam", "value", "where",
            "abstract", "actual", "annotation", "companion", "const", "crossinline", "data", "enum", "expect",
            "external", "final", "infix", "inline", "inner", "internal", "lateinit", "noinline", "open", "operator",
            "out", "override", "private", "protected", "public", "reified", "sealed", "suspend", "tailrec", "vararg",
        ],
        types: ["Int", "Long", "Double", "Float", "Boolean", "Char", "String", "Unit", "Any", "Nothing", "List", "Map", "Set"],
        constants: ["true", "false", "null", "this", "super"], annotation: ("@", .attribute), capitalizedTypes: true
    )

    private static let jsKeywords: Set<String> = [
        "break", "case", "catch", "class", "const", "continue", "debugger", "default", "delete", "do", "else", "export",
        "extends", "finally", "for", "function", "if", "import", "in", "instanceof", "new", "return", "super", "switch",
        "this", "throw", "try", "typeof", "var", "void", "while", "with", "yield", "let", "static", "async", "await",
        "of", "get", "set", "from", "as",
    ]
    private static let jsStrings = [
        StringRule("\"", "\""), StringRule("'", "'"), StringRule("`", "`", multiline: true),
    ]
    private static let jsConstants: Set<String> = ["true", "false", "null", "undefined", "NaN", "Infinity", "this", "super"]

    static let javascript = Syntax(
        lineComments: ["//"], blockComment: ("/*", "*/"), strings: jsStrings,
        keywords: jsKeywords, constants: jsConstants, capitalizedTypes: true, identifierExtras: "$"
    )

    static let typescript = Syntax(
        lineComments: ["//"], blockComment: ("/*", "*/"), strings: jsStrings,
        keywords: jsKeywords.union([
            "interface", "type", "enum", "implements", "declare", "namespace", "module", "abstract", "readonly",
            "private", "protected", "public", "keyof", "infer", "is", "satisfies", "override", "asserts", "accessor",
        ]),
        types: ["number", "string", "boolean", "any", "void", "never", "unknown", "object", "symbol", "bigint"],
        constants: jsConstants, annotation: ("@", .attribute), capitalizedTypes: true, identifierExtras: "$"
    )

    static let json = Syntax(
        lineComments: ["//"], blockComment: ("/*", "*/"), strings: [StringRule("\"", "\"")],
        constants: ["true", "false", "null"], functionCalls: false, memberProperties: false, stringKeys: true
    )

    static let php = Syntax(
        lineComments: ["//", "#"], blockComment: ("/*", "*/"),
        strings: [StringRule("\"", "\"", multiline: true), StringRule("'", "'", multiline: true)],
        keywords: [
            "abstract", "and", "array", "as", "break", "callable", "case", "catch", "class", "clone", "const",
            "continue", "declare", "default", "do", "echo", "else", "elseif", "empty", "enddeclare", "endfor",
            "endforeach", "endif", "endswitch", "endwhile", "enum", "extends", "final", "finally", "fn", "for",
            "foreach", "function", "global", "goto", "if", "implements", "include", "include_once", "instanceof",
            "insteadof", "interface", "isset", "list", "match", "namespace", "new", "or", "print", "private",
            "protected", "public", "readonly", "require", "require_once", "return", "static", "switch", "throw",
            "trait", "try", "unset", "use", "var", "while", "xor", "yield",
        ],
        types: ["int", "float", "bool", "string", "array", "object", "mixed", "void", "iterable", "never"],
        constants: ["true", "false", "null", "TRUE", "FALSE", "NULL", "self", "parent", "static"],
        annotation: ("#", .attribute), variablePrefix: "$", capitalizedTypes: true
    )

    static let python = Syntax(
        lineComments: ["#"],
        strings: [
            StringRule("\"\"\"", "\"\"\"", multiline: true), StringRule("'''", "'''", multiline: true),
            StringRule("\"", "\""), StringRule("'", "'"),
        ],
        keywords: [
            "and", "as", "assert", "async", "await", "break", "class", "continue", "def", "del", "elif", "else",
            "except", "finally", "for", "from", "global", "if", "import", "in", "is", "lambda", "nonlocal", "not",
            "or", "pass", "raise", "return", "try", "while", "with", "yield", "match", "case", "print",
        ],
        types: ["int", "float", "str", "bool", "list", "dict", "set", "tuple", "bytes", "object", "type"],
        constants: ["True", "False", "None", "self", "cls"], annotation: ("@", .attribute), capitalizedTypes: true
    )

    static let shell = Syntax(
        lineComments: ["#"],
        strings: [StringRule("\"", "\"", multiline: true), StringRule("'", "'", escape: nil, multiline: true)],
        keywords: [
            "if", "then", "else", "elif", "fi", "for", "while", "until", "do", "done", "case", "esac", "in",
            "function", "select", "time", "return", "exit", "export", "local", "readonly", "declare", "typeset",
            "unset", "shift", "source", "alias", "echo", "cd", "set", "test", "break", "continue", "printf", "read",
            "eval", "exec", "trap", "let",
        ],
        constants: ["true", "false"], variablePrefix: "$", functionCalls: false, memberProperties: false
    )

    static let sql = Syntax(
        lineComments: ["--"], blockComment: ("/*", "*/"),
        strings: [StringRule("'", "'", escape: nil, doubledClose: true), StringRule("\"", "\"", escape: nil)],
        keywords: [
            "select", "from", "where", "insert", "into", "values", "update", "set", "delete", "create", "table",
            "drop", "alter", "index", "view", "join", "inner", "left", "right", "outer", "full", "cross", "on", "as",
            "and", "or", "not", "null", "is", "in", "like", "ilike", "between", "order", "by", "group", "having",
            "limit", "offset", "distinct", "union", "all", "primary", "key", "foreign", "references", "default",
            "unique", "check", "constraint", "begin", "commit", "rollback", "transaction", "if", "exists", "case",
            "when", "then", "else", "end", "asc", "desc", "with", "returning", "cascade", "add", "column", "using",
            "replace", "trigger", "procedure", "function", "returns", "declare", "explain", "analyze", "vacuum",
        ],
        types: [
            "int", "integer", "varchar", "text", "char", "date", "timestamp", "datetime", "boolean", "float", "real",
            "numeric", "decimal", "serial", "bigint", "smallint", "blob", "json", "jsonb", "uuid", "double", "bytea",
        ],
        constants: ["null", "true", "false"], caseInsensitiveKeywords: true
    )

    static let go = Syntax(
        lineComments: ["//"], blockComment: ("/*", "*/"),
        strings: [StringRule("\"", "\""), StringRule("`", "`", escape: nil, multiline: true), StringRule("'", "'", maxLength: 8)],
        keywords: [
            "break", "case", "chan", "const", "continue", "default", "defer", "else", "fallthrough", "for", "func",
            "go", "goto", "if", "import", "interface", "map", "package", "range", "return", "select", "struct",
            "switch", "type", "var",
        ],
        types: [
            "bool", "byte", "complex64", "complex128", "error", "float32", "float64", "int", "int8", "int16", "int32",
            "int64", "rune", "string", "uint", "uint8", "uint16", "uint32", "uint64", "uintptr", "any",
        ],
        constants: ["true", "false", "nil", "iota"], capitalizedTypes: true
    )

    static let rust = Syntax(
        lineComments: ["//"], blockComment: ("/*", "*/"), nestedBlockComments: true,
        strings: [StringRule("\"", "\"", multiline: true), StringRule("'", "'", maxLength: 4)],
        keywords: [
            "as", "async", "await", "break", "const", "continue", "crate", "dyn", "else", "enum", "extern", "fn",
            "for", "if", "impl", "in", "let", "loop", "match", "mod", "move", "mut", "pub", "ref", "return",
            "static", "struct", "super", "trait", "type", "unsafe", "use", "where", "while", "macro_rules",
        ],
        types: [
            "i8", "i16", "i32", "i64", "i128", "isize", "u8", "u16", "u32", "u64", "u128", "usize", "f32", "f64",
            "bool", "char", "str", "String", "Vec", "Option", "Result", "Box", "Rc", "Arc", "Self",
        ],
        constants: ["true", "false", "self", "Self", "None", "Some", "Ok", "Err"], capitalizedTypes: true
    )

    static let ruby = Syntax(
        lineComments: ["#"],
        strings: [StringRule("\"", "\"", multiline: true), StringRule("'", "'", multiline: true)],
        keywords: [
            "alias", "and", "begin", "break", "case", "class", "def", "defined?", "do", "else", "elsif", "end",
            "ensure", "for", "if", "in", "module", "next", "not", "or", "redo", "rescue", "retry", "return", "then",
            "undef", "unless", "until", "when", "while", "yield", "require", "require_relative", "attr_accessor",
            "attr_reader", "attr_writer", "puts", "private", "public", "protected", "include", "extend", "lambda",
            "proc", "raise", "new", "super",
        ],
        constants: ["true", "false", "nil", "self"], variablePrefix: "@", capitalizedTypes: true, identifierExtras: "?!"
    )

    static let lua = Syntax(
        lineComments: ["--"], blockComment: ("--[[", "]]"),
        strings: [StringRule("[[", "]]", escape: nil, multiline: true), StringRule("\"", "\""), StringRule("'", "'")],
        keywords: [
            "and", "break", "do", "else", "elseif", "end", "for", "function", "if", "in", "local", "not", "or",
            "repeat", "return", "then", "until", "while", "goto",
        ],
        constants: ["true", "false", "nil", "self"]
    )

    static let perl = Syntax(
        lineComments: ["#"],
        strings: [StringRule("\"", "\""), StringRule("'", "'", escape: nil)],
        keywords: [
            "my", "our", "local", "sub", "if", "elsif", "else", "unless", "while", "until", "for", "foreach", "do",
            "last", "next", "redo", "return", "use", "no", "require", "package", "print", "printf", "die", "eval",
            "shift", "unshift", "push", "pop", "defined", "undef", "exists", "delete", "keys", "values", "each",
        ],
        variablePrefix: "$", functionCalls: false
    )

    static let makefile = Syntax(
        lineComments: ["#"], strings: [StringRule("\"", "\""), StringRule("'", "'", escape: nil)],
        keywords: ["ifeq", "ifneq", "ifdef", "ifndef", "else", "endif", "include", "define", "endef", "export", "override", "vpath"],
        variablePrefix: "$", functionCalls: false, memberProperties: false, lineLabels: true
    )

    static let dockerfile = Syntax(
        lineComments: ["#"], strings: [StringRule("\"", "\""), StringRule("'", "'", escape: nil)],
        keywords: [
            "from", "run", "cmd", "label", "maintainer", "expose", "env", "add", "copy", "entrypoint", "volume", "user",
            "workdir", "arg", "onbuild", "stopsignal", "healthcheck", "shell", "as",
        ],
        variablePrefix: "$", functionCalls: false, memberProperties: false, caseInsensitiveKeywords: true
    )
}
