import Foundation

/// Produces sorted-key JSON matching JavaScript's JSON.stringify output.
/// Keys are sorted lexicographically (Unicode code point order, same as JS).
/// Numbers are serialized without a trailing ".0" for whole values, matching
/// JS where 1.0 serializes as "1" and 1.5 serializes as "1.5".
enum CanonicalJSON {
    enum Value {
        case string(String)
        case number(Double)
        case null
    }

    static func encode(_ dict: [String: Value]) -> Data {
        let sorted = dict.keys.sorted()
        var result = "{"
        for (i, key) in sorted.enumerated() {
            if i > 0 { result += "," }
            result += "\"\(key.jsonEscaped)\":"
            switch dict[key]! {
            case .string(let s):
                result += "\"\(s.jsonEscaped)\""
            case .number(let n):
                // Match JS: whole-number doubles become integers ("1" not "1.0").
                if n.truncatingRemainder(dividingBy: 1) == 0,
                   !n.isInfinite, !n.isNaN,
                   n >= Double(Int64.min), n <= Double(Int64.max) {
                    result += String(Int64(n))
                } else {
                    result += String(n)
                }
            case .null:
                result += "null"
            }
        }
        result += "}"
        return result.data(using: .utf8)!
    }
}

private extension String {
    var jsonEscaped: String {
        var out = ""
        for ch in self.unicodeScalars {
            switch ch.value {
            case 0x22: out += "\\\""
            case 0x5C: out += "\\\\"
            case 0x08: out += "\\b"
            case 0x0C: out += "\\f"
            case 0x0A: out += "\\n"
            case 0x0D: out += "\\r"
            case 0x09: out += "\\t"
            case 0x00...0x1F:
                out += String(format: "\\u%04x", ch.value)
            default:
                out += String(ch)
            }
        }
        return out
    }
}
