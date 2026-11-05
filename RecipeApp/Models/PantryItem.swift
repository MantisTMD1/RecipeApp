import Foundation
import SwiftData

/// An ingredient the user has in their kitchen.
@Model
final class PantryItem {
    var name: String = ""
    var dateAdded: Date = Date.now

    init(name: String, dateAdded: Date = .now) {
        self.name = name
        self.dateAdded = dateAdded
    }
}
