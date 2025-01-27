//
//  Item.swift
//  Prod Log
//
//  Created by Joseph Muslu on 1/27/25.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
