//
//  TimerModulesWidgetBundle.swift
//  TimerModulesWidget
//
//  Created by Michael Fluharty on 5/21/26.
//

import WidgetKit
import SwiftUI

@main
struct TimerModulesWidgetBundle: WidgetBundle {
    var body: some Widget {
        TimerModulesWidget()
        TimerModulesWidgetControl()
        TimerModulesWidgetLiveActivity()
    }
}
