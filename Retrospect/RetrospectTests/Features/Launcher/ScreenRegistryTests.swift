@testable import Retrospect
import SwiftUI
import Testing

/// V2.registry: the launcher's screens come from groups, each in its own file. Every launch
/// argument that worked before the split (`-Screen <id> -State <state>`) still opens the same
/// screen, ids stay unique across groups, and the V2 groups add nothing until they have a screen.
@MainActor
struct ScreenRegistryTests {
    /// Every `-Screen <id> -State <state>` the launcher answered on main before the split
    /// (origin/main 52f3fb48). A screen may gain states; none of these may disappear. A PR that adds a
    /// core screen id adds it here too (e.g. #198's "player"), so a group line missed in a rebase fails.
    static let pinned: [String: [String]] = [
        "PI0": signIn,
        "AC-1": signIn,
        "PI1": [
            "promise", "promiseNeutral", "signingIn", "signInFailed", "typed", "typedWrong", "typedFilled",
            "used", "expired", "offline", "rateLimited", "waitlistSheet", "waitlisted", "suspended",
        ],
        "PI2": [
            "printing", "ready", "tearing", "sealing", "tearOffline", "tearRefused", "torn", "youreIn",
            "youreInStatic", "noName", "reduceMotion.ready",
        ],
        "first-run": ["questions", "questions-resume", "questions-offline", "privacy"],
        "journal": journal,
        "JR-1": journal,
        "AC-2": ["nothingWaiting", "unsent", "sending", "stuck", "offlineUnsent", "updateRequired", "done"],
        "account": ["rest", "unsent", "offline"],
        "PX": ["rest", "offline", "noStoreLink", "cover"],
    ]

    static let signIn = ["splash", "signingIn", "signInFailed", "offline", "returning", "restoring", "restoreFailed"]

    static let journal = [
        "full", "dayOne", "briefOff", "briefMaking", "briefQuiet", "briefPlayed", "briefError", "sending",
        "notSent", "offline", "loading", "error.network", "error.server", "guessOffered", "guessConfirmed",
        "guessPending", "guessError", "long", "searchHit", "searchEmpty", "tookRead", "tookWaiting",
        "tookNoted", "correction.applied", "correction.confirm", "correction.askOwnWords",
        "correction.notACorrection", "voice", "deleteDialog", "editing",
    ]

    @Test("every launch argument from before the split still resolves to its screen and state")
    func pinnedScenariosResolve() {
        for (id, states) in Self.pinned {
            let screen = ScreenRegistry.screen(id)
            #expect(screen != nil, "-Screen \(id) no longer resolves")
            for state in states {
                #expect(screen?.states.contains(state) == true, "-Screen \(id) -State \(state) no longer resolves")
            }
        }
    }

    @Test("every pinned scenario builds a view through the registry, as the launcher would")
    func pinnedScenariosBuild() {
        for (id, states) in Self.pinned {
            for state in states {
                let arguments = LaunchArguments.parse(["app", "-Screen", id, "-State", state])
                #expect(arguments.unknown.isEmpty)
                // the builder runs (no crash, no unknown-state page); the view itself is the group's test
                _ = ScreenRegistry.screen(id)?.build(arguments)
            }
        }
    }

    @Test("no group's screen is shadowed by another group's screen with the same id")
    func noScreenShadowed() {
        for group in ScreenRegistry.groups {
            for screen in group.screens {
                #expect(
                    ScreenRegistry.screen(screen.id)?.states == screen.states,
                    "\(group.name): \(screen.id) is shadowed by another group"
                )
            }
        }
    }

    @Test("ids are unique across groups, and so are group names")
    func unique() {
        let ids = ScreenRegistry.allIDs
        #expect(Set(ids).count == ids.count)
        let names = ScreenRegistry.groups.map { $0.name }
        #expect(Set(names).count == names.count)
    }

    @Test("every planned V2 group is registered once, so a screen PR edits only its group's file")
    func v2GroupsRegistered() {
        let names = Set(ScreenRegistry.groups.map { $0.name })
        for group in ["journal · v2", "podcasts", "you", "settings", "settings · trust", "goals", "outside the app", "shell"] {
            #expect(names.contains(group), "group \(group) is not registered")
        }
    }

    @Test("an id nothing registers is still unknown (the launcher shows the list, never crashes)")
    func unknownStaysUnknown() {
        #expect(ScreenRegistry.screen("NOPE") == nil)
    }
}
