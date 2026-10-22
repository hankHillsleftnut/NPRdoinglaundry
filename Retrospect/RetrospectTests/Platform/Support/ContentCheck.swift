import Foundation

/// The no-content check shared by the log and diagnostics tests: what a type
/// built from closed lists and numbers must never hold.
enum ContentCheck {
    /// Every String, Substring, Character, URL or Data anywhere inside `value`,
    /// through enums, structs, optionals and collections.
    static func values(in value: Any) -> [Any] {
        switch value {
        case is String, is Substring, is Character, is URL, is NSString, is NSURL, is Data, is NSData:
            return [value]
        default:
            return Mirror(reflecting: value).children.flatMap { values(in: $0.value) }
        }
    }
}
