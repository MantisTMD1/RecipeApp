import Foundation
import SwiftData
import UIKit

/// A recipe the user wrote themselves. Stored only on the device; the photo is a JPEG file
/// in Application Support so the database stays small.
@Model
final class CustomRecipe {
    static let idPrefix = "custom-"

    /// Same ID space as TheMealDB recipes, so favorites and navigation work unchanged.
    @Attribute(.unique) var recipeID: String
    var name: String
    var mealTypeRaw: String?
    var cuisine: String
    var instructions: String
    var ingredients: [RecipeIngredient]
    var photoFilename: String?
    var dateCreated: Date
    var dateModified: Date

    init(name: String) {
        recipeID = Self.idPrefix + UUID().uuidString
        self.name = name
        cuisine = ""
        instructions = ""
        ingredients = []
        dateCreated = .now
        dateModified = .now
    }

    var mealType: MealType? {
        get { mealTypeRaw.flatMap(MealType.init(rawValue:)) }
        set { mealTypeRaw = newValue?.rawValue }
    }

    var photoURL: URL? {
        photoFilename.map { Self.photosDirectory.appending(path: $0) }
    }

    var summary: MealSummary { MealSummary(id: recipeID, name: name, thumbnailURL: photoURL) }

    /// The same shape as a TheMealDB recipe, so every recipe screen can show it.
    var asMeal: Meal {
        Meal(id: recipeID,
             name: name,
             category: mealType?.title,
             area: cuisine.isEmpty ? nil : cuisine,
             instructions: instructions,
             thumbnailURL: photoURL,
             ingredients: ingredients
                .filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
                .map { Ingredient(name: $0.name, measure: $0.measure) })
    }

    static func isCustom(_ id: String) -> Bool { id.hasPrefix(idPrefix) }

    // MARK: Photo files

    static var photosDirectory: URL {
        let url = URL.applicationSupportDirectory.appending(path: "RecipePhotos")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Replaces the photo, writing a new file name each time so cached images refresh.
    func setPhoto(_ data: Data?) {
        deletePhotoFile()
        guard let data, let jpeg = Self.resizedJPEG(from: data) else {
            photoFilename = nil
            return
        }
        let filename = "\(UUID().uuidString).jpg"
        do {
            try jpeg.write(to: Self.photosDirectory.appending(path: filename))
            photoFilename = filename
        } catch {
            photoFilename = nil
        }
    }

    func deletePhotoFile() {
        if let url = photoURL { try? FileManager.default.removeItem(at: url) }
    }

    /// Shrinks large camera photos to at most 1600 px on the long side.
    private static func resizedJPEG(from data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let longest = max(image.size.width, image.size.height)
        let scale = min(1, 1600 / longest)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return resized.jpegData(compressionQuality: 0.8)
    }
}

struct RecipeIngredient: Codable, Hashable {
    var name: String
    var measure: String
}

extension ModelContext {
    /// Deletes a custom recipe, its photo, and any favorite pointing at it.
    func deleteCustomRecipe(_ recipe: CustomRecipe) {
        let id = recipe.recipeID
        let favorites = (try? fetch(FetchDescriptor<FavoriteMeal>(predicate: #Predicate { $0.mealID == id }))) ?? []
        favorites.forEach(delete)
        recipe.deletePhotoFile()
        delete(recipe)
    }
}
