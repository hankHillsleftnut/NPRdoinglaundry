//
//  ScreenTimeReport.swift
//  ScreenTimeReport
//
//  Entry point for the Device Activity Report Extension.
//  The system invokes this extension to render screen time summaries.
//

import DeviceActivity
import ExtensionKit
import SwiftUI

@main
struct ScreenTimeReport: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        TotalActivityReport { totalActivity in
            TotalActivityView(totalActivity: totalActivity)
        }
    }
}
