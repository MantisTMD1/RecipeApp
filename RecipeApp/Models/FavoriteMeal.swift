import Foundation
import SwiftData

/// A meal the user saved. Only the summary is stored; the full recipe is fetched on demand.
@Model
final class FavoriteMeal {
    @Attribute(.unique) var mealID: String
    var name: String
    var thumbnailURL: URL?
    var dateAdded: Date

    init(mealID: String, name: String, thumbnailURL: URL?, dateAdded: Date = .now) {
        self.mealID = mealID
        self.name = name
        self.thumbnailURL = thumbnailURL
        self.dateAdded = dateAdded
    }

    var summary: MealSummary {
        MealSummary(id: mealID, name: name, thumbnailURL: thumbnailURL)
    }
}
