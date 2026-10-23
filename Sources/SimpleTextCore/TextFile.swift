import Foundation

/// How the lines of a file end on disk. The editor keeps LF in memory and restores this on save.
public enum LineEnding: String, CaseIterable, Sendable {
    case lf = "LF"
    case crlf = "CRLF"
    case cr = "CR"

    public var string: String {
        switch self {
        case .lf: return "\n"
        case .crlf: return "\r\n"
        case .cr: return "\r"
        }
    }

    public var label: String {
        switch self {
        case .lf: return "LF (Unix, macOS)"
        case .crlf: return "CRLF (Windows)"
        case .cr: return "CR (Mac classique)"
        }
    }

    /// The ending most lines use, or nil when the text has no line break.
    public static func detect(in text: String) -> LineEnding? {
        var lf = 0, crlf = 0, cr = 0
        var previousWasCR = false
        for byte in text.utf8 {
            if byte == 13 {
                if previousWasCR { cr += 1 }
                previousWasCR = true
            } else if byte == 10 {
                if previousWasCR { crlf += 1 } else { lf += 1 }
                previousWasCR = false
            } else {
                if previousWasCR { cr += 1 }
                previousWasCR = false
            }
        }
        if previousWasCR { cr += 1 }
        if lf == 0 && crlf == 0 && cr == 0 { return nil }
        if crlf >= lf && crlf >= cr { return .crlf }
        if cr > lf { return .cr }
        return .lf
    }

    /// Turns every CRLF and CR into LF.
    public static func normalize(_ text: String) -> String {
        if !text.utf8.contains(13) { return text }
        return text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
    }
}

public struct DecodedText: Sendable {
    public var text: String
    public var encoding: String.Encoding
    public var hasBOM: Bool
    public var lineEnding: LineEnding?
}

public enum TextFileError: LocalizedError {
    case binary
    case undecodable
    case unencodable(String.Encoding)

    public var errorDescription: String? {
        switch self {
        case .binary: return "Ce fichier n’est pas un fichier texte."
        case .undecodable: return "Le texte de ce fichier n’a pu être décodé dans aucun encodage connu."
        case .unencodable(let encoding): return "Certains caractères n’existent pas en \(TextFile.name(of: encoding))."
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .binary: return "SimpleText n’ouvre que du texte ; les images, archives et exécutables sont refusés."
        case .undecodable: return nil
        case .unencodable: return "Choisissez UTF-8 dans la barre d’état avant d’enregistrer."
        }
    }
}

/// Reading and writing text files: binary refusal, encoding detection and line endings.
public enum TextFile {
    /// Encodings offered in the status bar, in display order.
    public static let encodings: [String.Encoding] = [
        .utf8, .utf16LittleEndian, .utf16BigEndian, .isoLatin1, .windowsCP1252, .macOSRoman, .ascii,
    ]

    public static func name(of encoding: String.Encoding) -> String {
        switch encoding {
        case .utf8: return "UTF-8"
        case .utf16LittleEndian: return "UTF-16 LE"
        case .utf16BigEndian: return "UTF-16 BE"
        case .utf16: return "UTF-16"
        case .isoLatin1: return "ISO Latin 1"
        case .windowsCP1252: return "Windows 1252"
        case .macOSRoman: return "Mac OS Roman"
        case .ascii: return "ASCII"
        default: return String.localizedName(of: encoding)
        }
    }

    /// A NUL byte in the first 8 KB: text files never have one, binary files almost always do.
    public static func isBinary(_ data: Data) -> Bool {
        data.prefix(8192).contains(0)
    }

    /// Decodes with the byte order mark, else as UTF-8, else `preferred`, else whatever Foundation recognises.
    public static func decode(_ data: Data, preferred: String.Encoding = .utf8) throws -> DecodedText {
        let (marked, hasBOM, body) = byteOrderMark(in: data)
        var decoded: (String, String.Encoding)?
        if let marked {
            if let text = String(data: body, encoding: marked) { decoded = (text, marked) }
        } else if let text = String(data: body, encoding: .utf8) {
            decoded = (text, .utf8)
        } else if preferred != .utf8, let text = String(data: body, encoding: preferred) {
            decoded = (text, preferred)
        } else {
            var converted: NSString?
            var lossy: ObjCBool = false
            let suggested = [String.Encoding.windowsCP1252, .isoLatin1, .macOSRoman].map { NSNumber(value: $0.rawValue) }
            let raw = NSString.stringEncoding(
                for: body,
                encodingOptions: [.suggestedEncodingsKey: suggested, .allowLossyKey: false],
                convertedString: &converted,
                usedLossyConversion: &lossy
            )
            if raw != 0, let converted {
                decoded = (converted as String, String.Encoding(rawValue: raw))
            } else if let text = String(data: body, encoding: .isoLatin1) {
                decoded = (text, .isoLatin1)
            }
        }
        guard let (text, usedEncoding) = decoded else { throw TextFileError.undecodable }
        let lineEnding = LineEnding.detect(in: text)
        return DecodedText(
            text: lineEnding == nil || lineEnding == .lf ? text : LineEnding.normalize(text),
            encoding: usedEncoding,
            hasBOM: hasBOM,
            lineEnding: lineEnding
        )
    }

    public static func encode(_ text: String, encoding: String.Encoding, bom: Bool, lineEnding: LineEnding) throws -> Data {
        let body = lineEnding == .lf ? text : text.replacingOccurrences(of: "\n", with: lineEnding.string)
        guard var data = body.data(using: encoding, allowLossyConversion: false) else {
            throw TextFileError.unencodable(encoding)
        }
        if bom, let mark = byteOrderMark(for: encoding) {
            data.insert(contentsOf: mark, at: 0)
        }
        return data
    }

    public static func byteOrderMark(for encoding: String.Encoding) -> [UInt8]? {
        switch encoding {
        case .utf8: return [0xEF, 0xBB, 0xBF]
        case .utf16LittleEndian: return [0xFF, 0xFE]
        case .utf16BigEndian: return [0xFE, 0xFF]
        default: return nil
        }
    }

    private static func byteOrderMark(in data: Data) -> (String.Encoding?, Bool, Data) {
        let bytes = [UInt8](data.prefix(3))
        if bytes.count >= 3, bytes[0] == 0xEF, bytes[1] == 0xBB, bytes[2] == 0xBF {
            return (.utf8, true, data.dropFirst(3))
        }
        if bytes.count >= 2 {
            if bytes[0] == 0xFF, bytes[1] == 0xFE { return (.utf16LittleEndian, true, data.dropFirst(2)) }
            if bytes[0] == 0xFE, bytes[1] == 0xFF { return (.utf16BigEndian, true, data.dropFirst(2)) }
        }
        return (nil, false, data)
    }
}
