//
//  RetrospectWidgetsBundle.swift
//  RetrospectWidgets
//
//  Created by Shaurya Narang on 12/1/25.
//

import SwiftUI
import WidgetKit

@main
struct RetrospectWidgetsBundle: WidgetBundle {
    var body: some Widget {
        if #available(iOS 18.0, *) {
            RetrospectWidgetsControl()
        }

        if #available(iOS 16.2, *) {
            VoiceRecordingLiveActivityWidget()
        }
    }
}
