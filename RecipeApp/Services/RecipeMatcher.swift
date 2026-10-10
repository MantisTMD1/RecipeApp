import Foundation

/// A recipe ranked against what the user has on hand.
struct RecipeSuggestion: Identifiable {
    let meal: Meal
    let have: [Ingredient]
    let missing: [Ingredient]

    var id: String { meal.id }
    var coverage: Double {
        let total = have.count + missing.count
        return total == 0 ? 0 : Double(have.count) / Double(total)
    }
}

/// Decides whether a recipe ingredient is covered by the user's kitchen.
struct IngredientMatcher {
    /// Basics most kitchens have; optionally treated as always available.
    static let staples: Set<String> = [
        "salt", "pepper", "black pepper", "water", "olive oil", "vegetable oil",
        "oil", "sugar", "plain flour", "flour", "butter", "sea salt", "ice cubes",
    ]

    private let pantry: [String]
    private let assumeStaples: Bool

    init(pantry: [String], assumeStaples: Bool) {
        self.pantry = pantry.map(Self.normalize)
        self.assumeStaples = assumeStaples
    }

    func has(_ ingredient: String) -> Bool {
        let name = Self.normalize(ingredient)
        if assumeStaples && Self.staples.contains(name) { return true }
        return pantry.contains { item in
            // "chicken" covers "chicken breast"; "cheddar cheese" covers "cheese".
            item == name || Self.containsWords(name, item) || Self.containsWords(item, name)
        }
    }

    static func normalize(_ string: String) -> String {
        var s = string.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        // Crude singularisation so "eggs" matches "egg" and "tomatoes" matches "tomato".
        s = s.split(separator: " ").map { word -> String in
            var w = String(word)
            if w.hasSuffix("oes") { w.removeLast(2) }
            else if w.hasSuffix("s") && !w.hasSuffix("ss") && w.count > 3 { w.removeLast() }
            return w
        }.joined(separator: " ")
        return s
    }

    /// True if every word of `needle` appears as a whole word in `haystack`, in order.
    private static func containsWords(_ haystack: String, _ needle: String) -> Bool {
        guard !needle.isEmpty else { return false }
        return " \(haystack) ".contains(" \(needle) ")
    }
}

enum RecipeMatcher {
    /// How many candidate recipes to load in full. Each one is a separate request.
    static let detailLimit = 25

    static func suggestions(for pantry: [String], assumeStaples: Bool) async throws -> [RecipeSuggestion] {
        guard !pantry.isEmpty else { return [] }
        let client = MealDBClient.shared

        // 1. Find meals that use each pantry ingredient and count the hits per meal.
        var hits: [String: (summary: MealSummary, count: Int)] = [:]
        try await withThrowingTaskGroup(of: [MealSummary].self) { group in
            for ingredient in pantry {
                group.addTask { (try? await client.meals(withIngredient: ingredient)) ?? [] }
            }
            for try await meals in group {
                for meal in meals {
                    hits[meal.id, default: (meal, 0)].count += 1
                }
            }
        }

        // 2. Load full recipes for the strongest candidates.
        let candidates = hits.values
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.summary.name < $1.summary.name }
            .prefix(detailLimit)
            .map(\.summary.id)

        var meals: [Meal] = []
        try await withThrowingTaskGroup(of: Meal?.self) { group in
            for id in candidates {
                group.addTask { try? await client.meal(id: id) }
            }
            for try await meal in group {
                if let meal { meals.append(meal) }
            }
        }

        // 3. Score each recipe by what's missing.
        let matcher = IngredientMatcher(pantry: pantry, assumeStaples: assumeStaples)
        return meals
            .map { meal in
                let have = meal.ingredients.filter { matcher.has($0.name) }
                let missing = meal.ingredients.filter { !matcher.has($0.name) }
                return RecipeSuggestion(meal: meal, have: have, missing: missing)
            }
            .sorted {
                if $0.missing.count != $1.missing.count { return $0.missing.count < $1.missing.count }
                if $0.coverage != $1.coverage { return $0.coverage > $1.coverage }
                return $0.meal.name < $1.meal.name
            }
    }
}
