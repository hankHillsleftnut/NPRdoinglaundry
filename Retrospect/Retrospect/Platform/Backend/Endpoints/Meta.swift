import Foundation

extension Backend {
    /// `GET /v2/meta` (contract 00 §5): the version floor, the newest version,
    /// the server's clock and which server this is.
    struct Meta: Decodable, Sendable, Equatable {
        let minVersion: String
        let latestVersion: String
        let serverTime: Date
        let environment: Server
    }
}

extension Backend.Meta {
    /// Which server answered. A value the app doesn't know decodes to `unknown`.
    enum Server: String, Flows.ContractEnum {
        case production, staging, local, unknown
    }
}

extension Backend.Endpoints {
    struct Meta: Backend.Endpoint {
        typealias Response = Backend.Meta

        var method: Backend.Method {
            .get
        }

        var path: Backend.PathTemplate {
            .meta
        }

        var requiresAuth: Bool {
            false
        }
    }
}
