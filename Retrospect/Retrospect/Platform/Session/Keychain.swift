import Foundation
import Security

extension Session {
    /// Generic-password storage for one Keychain service. `Session.Store` is
    /// its only user; tests use `Session.MemoryKeychain`.
    protocol KeychainBackend: Sendable {
        func read(_ account: String) throws -> Data?
        func write(_ data: Data, account: String) throws
        func delete(_ account: String) throws
        /// Every item in this backend's service.
        func deleteAll() throws
    }

    /// A Keychain call that failed, with the `OSStatus` it returned. Never
    /// carries the item's value.
    struct KeychainError: Error, Equatable, Sendable {
        let status: OSStatus
    }

    /// What the unlock probe found.
    enum UnlockProbe: Sendable, Equatable {
        case unlocked
        /// The phone hasn't been unlocked since it started.
        case locked
        /// The probe itself failed with this status; the phone's lock state is unknown.
        case failed(status: OSStatus)
    }

    /// The real Keychain. Every item is written `AfterFirstUnlockThisDeviceOnly`:
    /// readable in the background once the phone has been unlocked since it
    /// started (so the outbox can send while it's locked), never synced to
    /// iCloud, never restored to another device.
    struct SystemKeychain: KeychainBackend {
        let service: String

        func read(_ account: String) throws -> Data? {
            var query = Self.base(service: service, account: account)
            query[kSecReturnData as String] = true
            query[kSecMatchLimit as String] = kSecMatchLimitOne
            var result: AnyObject?
            let status = SecItemCopyMatching(query as CFDictionary, &result)
            switch status {
            case errSecSuccess: return result as? Data
            case errSecItemNotFound: return nil
            default: throw KeychainError(status: status)
            }
        }

        func write(_ data: Data, account: String) throws {
            let query = Self.base(service: service, account: account)
            let update = Self.attributes(data)
            let status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
            switch status {
            case errSecSuccess:
                return
            case errSecItemNotFound:
                let added = SecItemAdd(Self.addQuery(service: service, account: account, data: data) as CFDictionary, nil)
                guard added == errSecSuccess else { throw KeychainError(status: added) }
            default:
                throw KeychainError(status: status)
            }
        }

        func delete(_ account: String) throws {
            let status = SecItemDelete(Self.base(service: service, account: account) as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainError(status: status) }
        }

        func deleteAll() throws {
            let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service]
            let status = SecItemDelete(query as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainError(status: status) }
        }

        /// What every write sets: the value and its accessibility. An update sets
        /// both, so an item the old app wrote `WhenUnlocked` is moved over too.
        static func attributes(_ data: Data) -> [String: Any] {
            [kSecValueData as String: data, kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        }

        static func addQuery(service: String, account: String, data: Data) -> [String: Any] {
            base(service: service, account: account).merging(attributes(data)) { _, new in new }
        }

        private static func base(service: String, account: String) -> [String: Any] {
            [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
        }
    }

    /// An in-memory Keychain for tests and previews. Can be told to fail every
    /// call, or exactly one call counted from now.
    final class MemoryKeychain: KeychainBackend, @unchecked Sendable {
        private let lock = NSLock()
        private var items: [String: Data] = [:]
        private var everyCall: OSStatus?
        private var oneCall: (number: Int, status: OSStatus)?
        private var callsSinceArmed = 0

        init(_ items: [String: Data] = [:]) {
            self.items = items
        }

        /// Every item, by account.
        var contents: [String: Data] {
            lock.withLock { items }
        }

        /// From now on every call fails with `status`; nil makes calls work again.
        func failEveryCall(with status: OSStatus?) {
            lock.withLock { everyCall = status }
        }

        /// Only the `number`th call from now (1 is the next one) fails with
        /// `status`; every other call works.
        func failCall(_ number: Int, with status: OSStatus) {
            lock.withLock {
                oneCall = (number, status)
                callsSinceArmed = 0
            }
        }

        func read(_ account: String) throws -> Data? {
            try lock.withLock {
                try check()
                return items[account]
            }
        }

        func write(_ data: Data, account: String) throws {
            try lock.withLock {
                try check()
                items[account] = data
            }
        }

        func delete(_ account: String) throws {
            try lock.withLock {
                try check()
                items[account] = nil
            }
        }

        func deleteAll() throws {
            try lock.withLock {
                try check()
                items.removeAll()
            }
        }

        /// Called with the lock held.
        private func check() throws {
            if let everyCall {
                throw KeychainError(status: everyCall)
            }
            guard let oneCall else { return }
            callsSinceArmed += 1
            if callsSinceArmed == oneCall.number {
                self.oneCall = nil
                throw KeychainError(status: oneCall.status)
            }
        }
    }
}

extension Session.KeychainBackend {
    /// Whether the phone has been unlocked since it started: an
    /// `AfterFirstUnlock` item can be written only then. Writes and removes
    /// a probe item that holds no data. Only `errSecInteractionNotAllowed`
    /// means locked; any other status is a failure of its own (a build
    /// without the Keychain entitlement, say), never a reason to wait.
    func probeUnlock() -> UnlockProbe {
        let account = "unlock_probe"
        do {
            try write(Data(), account: account)
            try? delete(account)
            return .unlocked
        } catch let error as KeychainError where error.status == errSecInteractionNotAllowed {
            return .locked
        } catch let error as KeychainError {
            return .failed(status: error.status)
        } catch {
            return .failed(status: errSecInternalError)
        }
    }
}
