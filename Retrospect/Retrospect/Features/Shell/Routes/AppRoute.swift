//
//  AppRoute.swift
//  G0 (plan-glue.md §1c, §4): the one list of pages and sheets any group may open in another group.
//  A V2 group keeps its own typed routes for its own pages (YouRoute, GoalsRoute, SettingsRoute); what
//  crosses a group line is named here, once: the You picture opens settings, a goal row opens one goal,
//  "your words" opens one entry, the brief card opens the player, a transcript line opens why this is
//  here, a "this supports" row opens a node. Each case has ONE owning group, whose destinations file
//  (`Routes/Destinations/*`) builds the page; nobody else builds it (AppRouteTableTests).
//
//  Pushes are `AppRoute` (a page on the stack the control is in, with a back); sheets are `AppSheet`
//  (over the whole shell, tab bar included: G0b). The cases follow the journey map (SCREEN-MAP §3) and
//  the deep links `Routing.Destination` already parses (brief, entry, episode, settings page), so the
//  deep-link PR (W6) maps one table onto the other. Dark: Features/Shell is fenced from the release app
//  (ReleaseRouteTableTests, #205); the release root names none of this (AppRouteTableTests).
//
import Foundation

/// The group that owns a page: only its destinations file builds it.
enum AppRouteGroup: String, CaseIterable {
    case journal, podcasts, goals, you, settings, outside, account
}

/// A page pushed onto the stack of the control that opens it.
enum AppRoute: Hashable {
    /// JR-4 one entry (GL-2 "your words", YO "your words", deep link `entry`).
    case entry(id: String)
    /// GL-2 one goal (YO-3 "a goal" row).
    case goal(id: String)
    /// ST-1 and the pages it pushes (YO-1 your picture, the drawer foot, deep link `settings`).
    case settings(SettingsPage)
    /// YO-3 one source.
    case youSource(id: String)
    /// YO-5 what i know about you.
    case whatIKnow
    /// PC-3 why this is here, for one line of one episode (PC-2 transcript line).
    case whyThisIsHere(episodeID: String, lineID: String)

    /// ST-1 … ST-9, as settings' own stack names them (SettingsRoute, #224).
    enum SettingsPage: Hashable {
        case hub, dailyBrief, sources, privacy, howStraight, voice, learned, account
        case source(id: String)
    }

    /// The route without its ids: what a group builds or still owes.
    enum Kind: String, CaseIterable {
        case entry, goal, youSource, whatIKnow, whyThisIsHere
        case settingsHub, settingsDailyBrief, settingsSources, settingsSource, settingsPrivacy
        case settingsHowStraight, settingsVoice, settingsLearned, settingsAccount
    }

    var kind: Kind {
        switch self {
        case .entry: .entry
        case .goal: .goal
        case .youSource: .youSource
        case .whatIKnow: .whatIKnow
        case .whyThisIsHere: .whyThisIsHere
        case let .settings(page):
            switch page {
            case .hub: .settingsHub
            case .dailyBrief: .settingsDailyBrief
            case .sources: .settingsSources
            case .source: .settingsSource
            case .privacy: .settingsPrivacy
            case .howStraight: .settingsHowStraight
            case .voice: .settingsVoice
            case .learned: .settingsLearned
            case .account: .settingsAccount
            }
        }
    }

    /// The group that builds this page.
    var owner: AppRouteGroup {
        kind.owner
    }
}

extension AppRoute.Kind {
    var owner: AppRouteGroup {
        switch self {
        case .entry: .journal
        case .goal: .goals
        case .youSource, .whatIKnow: .you
        case .whyThisIsHere: .podcasts
        case .settingsHub, .settingsDailyBrief, .settingsSources, .settingsSource, .settingsPrivacy,
             .settingsHowStraight, .settingsVoice, .settingsLearned, .settingsAccount: .settings
        }
    }
}

/// A sheet over the whole shell (it covers the tab bar: G0b). Never two at once (RSheetHost).
enum AppSheet: Hashable, Identifiable {
    /// JR-2 today's brief (nil) or one brief (JR-1 brief card, ST-2 "play today's", deep link `brief`).
    case brief(id: String?)
    /// PC-2 the player on one episode (PC-1 hero, the mini-player, deep link `episode`).
    case episode(id: String)
    /// YO-4 one node, the person sheet.
    case node(id: String)
    /// EX-1 share, as the app shows it (the extension is W7's).
    case share
    /// AC-2 signing out (ST-9 sign out).
    case signOut

    enum Kind: String, CaseIterable {
        case brief, episode, node, share, signOut
    }

    var id: Self {
        self
    }

    var kind: Kind {
        switch self {
        case .brief: .brief
        case .episode: .episode
        case .node: .node
        case .share: .share
        case .signOut: .signOut
        }
    }

    var owner: AppRouteGroup {
        kind.owner
    }
}

extension AppSheet.Kind {
    var owner: AppRouteGroup {
        switch self {
        case .brief: .journal
        case .episode: .podcasts
        case .node: .you
        case .share: .outside
        case .signOut: .account
        }
    }
}
