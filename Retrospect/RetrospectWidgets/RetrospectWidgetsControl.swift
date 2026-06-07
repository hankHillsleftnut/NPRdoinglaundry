//
//  RetrospectWidgetsControl.swift
//  RetrospectWidgets
//
//  Created by Shaurya Narang on 12/1/25.
//

import AppIntents
import SwiftUI
import WidgetKit

struct RetrospectWidgetsControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: "com.shauryanarang.Retrospect.startVoiceNote"
        ) {
            ControlWidgetButton(
                action: OpenURLIntent(URL(string: "retrospect://start-recording")!)
            ) {
                Label("Retrospect Note", systemImage: "waveform")
            }
        }
        .displayName("Retrospect Note")
        .description("Start a new audio note in Retrospect.")
    }
}
