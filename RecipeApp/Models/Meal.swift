import Foundation

/// A meal category, e.g. "Seafood" or "Dessert".
struct MealCategory: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let thumbnailURL: URL?
    let description: String

    enum CodingKeys: String, CodingKey {
        case id = "idCategory"
        case name = "strCategory"
        case thumbnailURL = "strCategoryThumb"
        case description = "strCategoryDescription"
    }
}

/// The short form of a meal returned by list endpoints (filter by category, etc.).
struct MealSummary: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let thumbnailURL: URL?

    enum CodingKeys: String, CodingKey {
        case id = "idMeal"
        case name = "strMeal"
        case thumbnailURL = "strMealThumb"
    }

    init(id: String, name: String, thumbnailURL: URL?) {
        self.id = id
        self.name = name
        self.thumbnailURL = thumbnailURL
    }
}

/// An entry from TheMealDB's master ingredient list.
struct IngredientInfo: Decodable, Identifiable, Hashable {
    let id: String
    let name: String

    enum CodingKeys: String, CodingKey {
        case id = "idIngredient"
        case name = "strIngredient"
    }

    /// Small product image hosted by TheMealDB.
    var thumbnailURL: URL? {
        let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
        return URL(string: "https://www.themealdb.com/images/ingredients/\(encoded)-small.png")
    }
}

struct Ingredient: Hashable, Identifiable {
    let name: String
    let measure: String
    var id: String { name + measure }
}

/// A full recipe from search, lookup, or random endpoints.
struct Meal: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let category: String?
    let area: String?
    let instructions: String
    let thumbnailURL: URL?
    let tags: [String]
    let youtubeURL: URL?
    let sourceURL: URL?
    let ingredients: [Ingredient]

    var summary: MealSummary {
        MealSummary(id: id, name: name, thumbnailURL: thumbnailURL)
    }

    /// Estimated from the instructions; TheMealDB has no time field.
    var cookTime: CookTime { CookTime(instructions: instructions) }

    /// TheMealDB uses flat keys (strIngredient1...20), so decode with dynamic keys.
    private struct Key: CodingKey {
        let stringValue: String
        init(_ string: String) { stringValue = string }
        init?(stringValue: String) { self.stringValue = stringValue }
        var intValue: Int? { nil }
        init?(intValue: Int) { nil }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Key.self)

        func string(_ key: String) -> String? {
            let value = (try? c.decodeIfPresent(String.self, forKey: Key(key))) ?? nil
            let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
            return (trimmed?.isEmpty ?? true) ? nil : trimmed
        }

        id = try c.decode(String.self, forKey: Key("idMeal"))
        name = try c.decode(String.self, forKey: Key("strMeal"))
        category = string("strCategory")
        area = string("strArea")
        instructions = string("strInstructions") ?? ""
        thumbnailURL = string("strMealThumb").flatMap(URL.init(string:))
        tags = string("strTags")?
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty } ?? []
        youtubeURL = string("strYoutube").flatMap(URL.init(string:))
        sourceURL = string("strSource").flatMap(URL.init(string:))

        // Some recipes list the same ingredient twice (e.g. for a marinade and a sauce);
        // merge those into one entry with both measures.
        var merged: [Ingredient] = []
        for i in 1...20 {
            guard let name = string("strIngredient\(i)") else { continue }
            let measure = string("strMeasure\(i)") ?? ""
            if let index = merged.firstIndex(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
                let existing = merged[index].measure
                let combined = [existing, measure].filter { !$0.isEmpty }.joined(separator: " + ")
                merged[index] = Ingredient(name: merged[index].name, measure: combined)
            } else {
                merged.append(Ingredient(name: name, measure: measure))
            }
        }
        ingredients = merged
    }
}
