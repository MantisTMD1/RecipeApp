import Foundation
import SwiftData

/// Something the user needs to buy.
@Model
final class ShoppingItem {
    var name: String
    var measure: String
    /// Names of the recipes this item was added for, so the list can say why it's there.
    var recipes: [String]
    var isChecked: Bool
    var dateAdded: Date

    init(name: String, measure: String = "", recipe: String? = nil) {
        self.name = name
        self.measure = measure
        self.recipes = recipe.map { [$0] } ?? []
        self.isChecked = false
        self.dateAdded = .now
    }
}

extension ModelContext {
    /// Adds ingredients to the shopping list, merging with items already on it.
    /// Returns how many new items were created.
    @discardableResult
    func addToShoppingList(_ ingredients: [Ingredient], from recipe: String?) -> Int {
        let existing = (try? fetch(FetchDescriptor<ShoppingItem>())) ?? []
        var added = 0
        for ingredient in ingredients {
            let key = IngredientMatcher.normalize(ingredient.name)
            if let item = existing.first(where: { IngredientMatcher.normalize($0.name) == key }) {
                item.isChecked = false
                if let recipe, !item.recipes.contains(recipe) { item.recipes.append(recipe) }
            } else {
                insert(ShoppingItem(name: ingredient.name, measure: ingredient.measure, recipe: recipe))
                added += 1
            }
        }
        return added
    }
}
