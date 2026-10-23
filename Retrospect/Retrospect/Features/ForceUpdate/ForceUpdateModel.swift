//
//  ForceUpdateModel.swift
//  PX: the force-update page's one decision: can the person be sent to the App Store? The link is built
//  from the App Store id in the build configuration (Info.plist key `AppStoreID`), never a literal; with
//  no id yet the words stay and the button is hidden (not disabled). No network here: the opener is a seam.
//
import Foundation
import Observation

/// The App Store page for this app, from build configuration.
enum AppStoreLink {
    static let infoKey = "AppStoreID"

    /// `itms-apps://apps.apple.com/app/id<id>`; nil for an empty or non-numeric id (never a guess).
    static func url(id: String?) -> URL? {
        guard let trimmed = id?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty,
              trimmed.allSatisfy(\.isNumber)
        else { return nil }
        return URL(string: "itms-apps://apps.apple.com/app/id\(trimmed)")
    }

    /// The id the build was configured with, if any.
    static func configuredID(in bundle: Bundle = .main) -> String? {
        bundle.object(forInfoDictionaryKey: infoKey) as? String
    }
}

@MainActor @Observable
final class ForceUpdateModel {
    /// The store link, or nil while the founder hasn't supplied the id.
    let storeURL: URL?
    @ObservationIgnored private let open: (URL) -> Void
    /// Counts the presses, for the haptic.
    private(set) var presses = 0

    init(storeURL: URL? = AppStoreLink.url(id: AppStoreLink.configuredID()), open: @escaping (URL) -> Void) {
        self.storeURL = storeURL
        self.open = open
    }

    /// The button shows only when there is somewhere to send the person.
    var canUpdate: Bool {
        storeURL != nil
    }

    func update() {
        guard let storeURL else { return }
        presses += 1
        open(storeURL)
    }

    // MARK: Words (strings in one place: the page is a purpose page, the words are the founder's)

    static let title = "there's a newer retrospect."
    static let line = "this version can't keep up any more. update to keep going; nothing you've saved is lost."
    static let button = "update"
    static let buttonLabel = "update retrospect in the App Store"
}
