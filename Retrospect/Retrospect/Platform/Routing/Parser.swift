import Foundation

extension Routing {
    /// Reads an address into a destination. Pure: no state, no logging.
    enum Parser {
        /// The invite link: `<base>/i/<code>`. Only the base's own scheme, host and port count.
        /// The code is normalised as `Session.InviteCode` does and must be exactly 13 characters.
        static func parse(_ url: URL, inviteBase: URL?) -> Destination? {
            switch url.scheme?.lowercased() {
            case "retrospect":
                parseApp(url)
            default:
                parseInvite(url, base: inviteBase)
            }
        }

        /// What an address that did not parse should be logged as.
        static func unknownKind(of url: URL, inviteBase: URL?) -> UnknownKind {
            if url.scheme?.lowercased() == "retrospect" {
                return .appLink
            }
            if let base = inviteBase, sameOrigin(url, base) {
                return .inviteHostLink
            }
            return .other
        }

        /// The Google sign-in's return address: the old Google flow owns it, so it is neither a
        /// destination nor an unknown link.
        static func isGoogleCallback(_ url: URL) -> Bool {
            url.scheme?.lowercased().hasPrefix("com.googleusercontent.apps.") == true
        }

        // MARK: retrospect://

        private static func parseApp(_ url: URL) -> Destination? {
            guard let host = url.host?.lowercased() else { return nil }
            let parts = url.pathComponents.filter { $0 != "/" }
            switch host {
            case "start-recording": return parts.isEmpty ? .startRecording : nil
            case "stop-recording": return parts.isEmpty ? .stopRecording : nil
            case "integration-connected": return parts.isEmpty ? integration(url) : nil
            case "brief": return brief(parts)
            case "entry": return id(parts).map(Destination.entry)
            case "episode": return id(parts).map(Destination.episode)
            case "guess": return id(parts).map(Destination.guess)
            case "settings": return settings(parts)
            default: return nil
            }
        }

        private static func integration(_ url: URL) -> Destination? {
            let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
            guard let provider = items.first(where: { $0.name == "provider" })?.value, isName(provider),
                  let status = items.first(where: { $0.name == "status" })?.value, isName(status) else { return nil }
            return .integrationConnected(provider: provider, status: status)
        }

        private static func brief(_ parts: [String]) -> Destination? {
            switch parts.count {
            case 0: .brief(id: nil)
            case 1: id(parts).map { .brief(id: $0) }
            default: nil
            }
        }

        private static func settings(_ parts: [String]) -> Destination? {
            switch parts.count {
            case 0: .settings(.root)
            case 1: Destination.SettingsPage(rawValue: parts[0]).map { .settings($0) }
            default: nil
            }
        }

        /// Exactly one path part, and it is a UUID (kept as written, lowercased).
        private static func id(_ parts: [String]) -> String? {
            guard parts.count == 1, UUID(uuidString: parts[0]) != nil else { return nil }
            return parts[0].lowercased()
        }

        /// A short name: lowercase letters, digits, `_` and `-`.
        private static func isName(_ value: String) -> Bool {
            !value.isEmpty && value.count <= 40
                && value.allSatisfy { $0.isASCII && ($0.isLowercase || $0.isNumber || $0 == "_" || $0 == "-") }
        }

        // MARK: https://<invite host>/i/<code>

        private static func parseInvite(_ url: URL, base: URL?) -> Destination? {
            guard let base, sameOrigin(url, base) else { return nil }
            let parts = url.pathComponents.filter { $0 != "/" }
            guard parts.count == 2, parts[0] == "i", let code = Session.InviteCode.normalise(parts[1]) else { return nil }
            return .invite(code: code)
        }

        /// The port as the web sees it: an explicit default (`:443` for https, `:80` for http) is no port.
        private static func port(of url: URL) -> Int? {
            let scheme = url.scheme?.lowercased()
            if let port = url.port { return port == (scheme == "https" ? 443 : scheme == "http" ? 80 : -1) ? nil : port }
            return nil
        }

        private static func sameOrigin(_ url: URL, _ base: URL) -> Bool {
            guard let host = url.host?.lowercased(), host == base.host?.lowercased() else { return false }
            return url.scheme?.lowercased() == base.scheme?.lowercased() && port(of: url) == port(of: base)
        }
    }
}
