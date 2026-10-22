import Foundation

/// The only thing `NoteSyncQueue` needs from the network layer.
///
/// The queue is written against this protocol rather than `RetrospectAPIClient`
/// directly so the drain loop can be exercised against a stub, and so the client
/// keeps owning transport concerns (base URL, keychain token, 401 handling).
@MainActor
protocol NoteUploading {
    /// True when a request would carry a usable bearer token. The queue checks
    /// this before draining so a signed-out user parks work instead of burning
    /// retry attempts on requests that cannot succeed.
    var canUpload: Bool { get }
    var currentUserId: String? { get }

    /// Upload one captured note. `clientUuid` is the idempotency key: the backend
    /// upserts on (user_id, client_uuid), so the same note may be sent any number
    /// of times and still produce exactly one row.
    func uploadNote(
        clientUuid: UUID,
        contentType: String,
        content: String,
        contentDate: Date,
        metadata: [String: String]?
    ) async throws
}

// MARK: - RetrospectAPIClient Adapter

// Lives here rather than in RetrospectAPIClient.swift so the client file stays
// untouched. Requires `uploadContent` to accept a `clientUuid` — see the one-line
// change documented alongside this work.
extension RetrospectAPIClient: NoteUploading {
    var canUpload: Bool {
        isAuthenticated
    }

    func uploadNote(
        clientUuid: UUID,
        contentType: String,
        content: String,
        contentDate: Date,
        metadata: [String: String]?
    ) async throws {
        try await uploadContent(
            contentType: contentType,
            content: content,
            contentDate: contentDate,
            metadata: metadata.map { $0 as [String: Any] },
            clientUuid: clientUuid.uuidString.lowercased()
        )
    }
}

// MARK: - Failure Classification

/// How the queue should react to a failed upload.
enum NoteUploadDisposition {
    /// Worth trying again on a backoff schedule (offline, timeout, 5xx, 429).
    case retry
    /// The user is signed out or the token expired. Park the note untouched and
    /// wait for auth to come back — never count this against the note's attempts.
    case waitForAuth
    /// The server rejected the payload itself (4xx that is not auth or rate
    /// limiting). Retrying the identical body will not help, so the note stops
    /// cycling — but it stays on disk and gets a fresh chance next launch.
    case blocked
}

extension NoteUploadDisposition {
    /// Classify an error thrown by `NoteUploading.uploadNote`.
    ///
    /// `APIError.serverError` carries its status code in the message ("HTTP 503: …"),
    /// which is the only signal available without changing the API client.
    static func classify(_ error: Error) -> NoteUploadDisposition {
        if let apiError = error as? APIError {
            switch apiError {
            case .notAuthenticated, .authFailed:
                return .waitForAuth
            case .invalidURL, .invalidResponse:
                return .retry
            case .serverError(let message):
                return classifyServerError(message)
            }
        }

        // URLError and anything else unrecognised is treated as transient. The
        // cost of retrying a permanent failure is a slow poll; the cost of
        // giving up on a transient one is a lost note.
        return .retry
    }

    private static func classifyServerError(_ message: String) -> NoteUploadDisposition {
        guard message.hasPrefix("HTTP "),
              let colonIndex = message.firstIndex(of: ":"),
              let statusCode = Int(message[message.index(message.startIndex, offsetBy: 5)..<colonIndex]) else {
            return .retry
        }

        switch statusCode {
        // 403 is deliberately NOT auth here. The backend's auth middleware only
        // ever answers 401, and the API client converts that to .authFailed long
        // before this point — so a 403 comes from an edge or a gateway, and
        // parking the whole queue on it would stall every note behind this one.
        case 401:
            return .waitForAuth
        case 408, 429:
            return .retry
        case 500...599:
            return .retry
        case 400...499:
            return .blocked
        default:
            return .retry
        }
    }
}
