//
//  TimerModulesWidgetLiveActivity.swift
//  TimerModulesWidget
//
//  Created by Michael Fluharty on 5/21/26.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct TimerModulesWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct TimerModulesWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimerModulesWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension TimerModulesWidgetAttributes {
    fileprivate static var preview: TimerModulesWidgetAttributes {
        TimerModulesWidgetAttributes(name: "World")
    }
}

extension TimerModulesWidgetAttributes.ContentState {
    fileprivate static var smiley: TimerModulesWidgetAttributes.ContentState {
        TimerModulesWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: TimerModulesWidgetAttributes.ContentState {
         TimerModulesWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: TimerModulesWidgetAttributes.preview) {
   TimerModulesWidgetLiveActivity()
} contentStates: {
    TimerModulesWidgetAttributes.ContentState.smiley
    TimerModulesWidgetAttributes.ContentState.starEyes
}
