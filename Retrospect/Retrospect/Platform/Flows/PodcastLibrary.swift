//
//  PodcastLibrary.swift
//  PL3.4.a.min (Alpha 0.1): what the podcast library looks like to a screen or another seam. The library
//  and episode shapes are FR.doors' contract-03 types (Backend.Podcasts), named here so callers say
//  `Flows.Podcasts.Library`; this file adds only the page's state and the seam's protocol.
//
import Foundation
import Observation

extension Flows {
    enum Podcasts {
        typealias Library = Backend.Podcasts.Library
        typealias Episode = Backend.Podcasts.Episode
        typealias EpisodeSummary = Backend.Podcasts.EpisodeSummary

        /// Where the library is.
        enum LibraryState: Equatable, Sendable {
            /// Nothing known yet: never carries an older answer.
            case loading
            case content(Library)
            /// The phone can't reach the server; the last good library, when there is one, is still shown.
            case offline(Library?)
            /// The first load failed for another reason, with nothing to show.
            case failed(Failure)

            /// The library to show, if any.
            var library: Library? {
                switch self {
                case let .content(library): library
                case let .offline(library): library
                case .loading, .failed: nil
                }
            }
        }
    }

    /// The podcast library, as a page or another seam (the first episode) reads it. Built per signed-in person.
    @MainActor
    protocol PodcastsData: AnyObject, Observable {
        var state: Podcasts.LibraryState { get }
        /// The first load: the kept library at once if there is one, then the server. Returns the state after it.
        @discardableResult
        func library() async -> Podcasts.LibraryState
        /// Asks the server again; what is shown stays until a new answer replaces it.
        func refresh() async
        /// One episode with its signed audio link (good for an hour).
        func episode(id: String) async -> Result<Podcasts.Episode, Failure>
    }
}

extension Flows.Podcasts.LibraryState: CustomStringConvertible, CustomDebugStringConvertible {
    /// Only which state it is: titles are the person's own content, so a state interpolated into a line never carries them.
    var description: String {
        switch self {
        case .loading: "loading"
        case .content: "content"
        case .offline: "offline"
        case .failed: "failed"
        }
    }

    var debugDescription: String {
        description
    }
}
