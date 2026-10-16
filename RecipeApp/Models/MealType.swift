import Foundation

/// Breakfast, lunch, dinner or dessert. TheMealDB only has a "Breakfast" category,
/// so the others are built from categories and name searches that usually fit that meal.
enum MealType: String, CaseIterable, Identifiable {
    case breakfast, lunch, dinner, dessert

    var id: String { rawValue }

    var title: String {
        switch self {
        case .breakfast: "Breakfast"
        case .lunch: "Lunch"
        case .dinner: "Dinner"
        case .dessert: "Dessert"
        }
    }

    var systemImage: String {
        switch self {
        case .breakfast: "sunrise"
        case .lunch: "sun.max"
        case .dinner: "moon.stars"
        case .dessert: "birthday.cake"
        }
    }

    /// TheMealDB categories that belong to this meal.
    var categories: [String] {
        switch self {
        case .breakfast: ["Breakfast"]
        case .lunch: ["Starter", "Pasta"]
        case .dinner: ["Beef", "Chicken", "Lamb", "Pork", "Seafood", "Goat", "Vegetarian", "Vegan"]
        case .dessert: ["Dessert"]
        }
    }

    /// Name searches for lighter dishes; results must contain the word, not just the letters
    /// (so "wrap" doesn't match "wrapped").
    var nameSearches: [String] {
        switch self {
        case .lunch: ["soup", "salad", "sandwich", "wrap", "burger"]
        default: []
        }
    }
}

extension MealDBClient {
    /// Every recipe that fits a meal type, without duplicates.
    func meals(for type: MealType) async -> [MealSummary] {
        await withTaskGroup(of: [MealSummary].self) { group in
            for category in type.categories {
                group.addTask { (try? await meals(inCategory: category)) ?? [] }
            }
            for term in type.nameSearches {
                group.addTask {
                    let results = (try? await search(term)) ?? []
                    return results
                        .filter { Self.containsWord(term, in: $0.name) }
                        .map(\.summary)
                }
            }
            var seen = Set<String>()
            var all: [MealSummary] = []
            for await batch in group {
                for meal in batch where seen.insert(meal.id).inserted { all.append(meal) }
            }
            return all
        }
    }

    private static func containsWord(_ word: String, in text: String) -> Bool {
        text.lowercased()
            .components(separatedBy: CharacterSet.letters.inverted)
            .contains { $0 == word || $0 == word + "s" }
    }
}
