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

    /// `itms-apps://apps.apple.com/app/id<id>`; nil for an empty id or anything but ASCII digits (never a
    /// guess: `Character.isNumber` would also let "½" or Arabic-Indic digits into the link).
    static func url(id: String?) -> URL? {
        guard let trimmed = id?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty,
              trimmed.allSatisfy({ $0.isASCII && $0.isWholeNumber })
        else { return nil }
        return URL(string: "itms-apps://apps.apple.com/app/id\(trimmed)")
    }

    /// The id the build was configured with, if any.
    static func configuredID(in bundle: Bundle = .main) -> String? {
        // A plist key typed as a Number (easy in Xcode's editor) is as good as a String.
        switch bundle.object(forInfoDictionaryKey: infoKey) {
        case let string as String: string
        case let number as NSNumber: number.stringValue
        default: nil
        }
    }
}

@MainActor @Observable
final class ForceUpdateModel {
    /// The store link, or nil while the founder hasn't supplied the id.
    let storeURL: URL?
    @ObservationIgnored private let open: (URL) -> Void

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
        open(storeURL) // the press haptic is RButton's own (primary variant)
    }

    // MARK: Words (strings in one place: the page is a purpose page, the words are the founder's)

    static let title = "there's a newer retrospect."
    static let line = "this version can't keep up any more. update to keep going; nothing you've saved is lost."
    static let button = "update"
    static let buttonLabel = "update retrospect in the App Store"
}
