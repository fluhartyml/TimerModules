//
//  Item.swift
//  TimerModules
//
//  Created by Michael Fluharty on 5/16/26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date = Date()

    init(timestamp: Date = Date()) {
        self.timestamp = timestamp
    }
}
