//
//  Settings.swift
//  V2.settings: what the settings pages (ST-1 … ST-9) read and change, as a screen sees it. The
//  shape follows the PL3.7.0 card (docs/team/flows/settings/platform.md) so live data can replace
//  the sample later without a page changing. V2 has a SAMPLE implementation only
//  (Features/Settings/Sample): nothing here talks to the server or saves anything. This is the
//  first half's part (ST-1 … ST-4); ST-5 … ST-9 add theirs in their own files.
//
import Foundation
import Observation

extension Flows {
    enum Settings {
        /// A time of day on the phone's clock ("8:30 am").
        struct LocalTime: Hashable, Sendable {
            let hour: Int
            let minute: Int

            /// "8:30": ST-1's value.
            var short: String {
                let twelve = hour % 12 == 0 ? 12 : hour % 12
                return "\(twelve):" + String(format: "%02d", minute)
            }

            /// "8:30 am": ST-2's value.
            var long: String {
                short + (hour < 12 ? " am" : " pm")
            }
        }

        enum BriefLength: String, CaseIterable, Sendable {
            case short, standard, long
        }

        /// Today's brief, when there is one ("tuesday · 4 min").
        struct TodaysBrief: Equatable, Sendable {
            let day: String
            let minutes: Int
        }

        /// The daily brief's settings (ST-2).
        struct Brief: Equatable, Sendable {
            var isOn: Bool
            var time: LocalTime
            var length: BriefLength
            /// The time zone's city ("london"), for "your time, london".
            var city: String
            var today: TodaysBrief?
            /// About how long each length runs, in minutes.
            var minutes: [BriefLength: Int]
        }

        /// Whether retro speaks its replies or only writes them (ST-1, ST-7).
        enum TalkOrRead: String, CaseIterable, Sendable {
            case talk, read
        }

        enum SourceStatus: Equatable, Sendable {
            case connected, syncing, needsYou, notConnected
        }

        /// A place retro learns from (ST-3, ST-4).
        struct Source: Identifiable, Equatable, Sendable {
            let id: String
            let name: String
            /// Why it's there ("so your brief knows your day"), or what went wrong.
            var purpose: String
            /// The SF Symbol in its well.
            let symbol: String
            var status: SourceStatus
            /// What it reads, in one plain sentence (ST-4), when its page is drawn.
            var reads: String?
            /// What it helps retro see (ST-4).
            var helpsMeSee: String?
            /// "last read 2 min ago".
            var lastRead: String?

            /// Whether this source has its own page (ST-4): one is drawn for it, and it is connected
            /// (a disconnected source only offers "connect").
            var hasPage: Bool {
                reads != nil && helpsMeSee != nil && status != .notConnected
            }
        }
    }

    /// The settings, as the settings pages read and change them. Writes apply at once.
    @MainActor
    protocol SettingsData: AnyObject, Observable {
        var brief: Settings.Brief { get }
        /// The times the brief's quick pick offers.
        var briefTimes: [Settings.LocalTime] { get }
        var talkOrRead: Settings.TalkOrRead { get }
        /// The voice's name ("warm"), shown on ST-1; ST-7 changes it.
        var voiceName: String { get }
        /// How straight retro is, in a word ("honest"), shown on ST-1; ST-6 changes it.
        var straightnessName: String { get }
        var sources: [Settings.Source] { get }

        func setBrief(isOn: Bool)
        func setBrief(time: Settings.LocalTime)
        func setBrief(length: Settings.BriefLength)
        func setTalkOrRead(_ value: Settings.TalkOrRead)

        func connect(_ id: Settings.Source.ID) async
        func sync(_ id: Settings.Source.ID) async
        func disconnect(_ id: Settings.Source.ID) async
        func deleteData(of id: Settings.Source.ID) async
    }
}

extension Flows.SettingsData {
    func source(_ id: Flows.Settings.Source.ID) -> Flows.Settings.Source? {
        sources.first { $0.id == id }
    }
}
