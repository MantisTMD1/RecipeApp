import Foundation

/// Nutrients for some amount of food. Sodium is in milligrams; the rest are grams or kcal.
struct NutritionFacts: Equatable {
    var calories = 0.0
    var protein = 0.0
    var carbs = 0.0
    var fat = 0.0
    var fiber = 0.0
    var sugar = 0.0
    var sodium = 0.0

    func multiplied(by factor: Double) -> NutritionFacts {
        NutritionFacts(calories: calories * factor, protein: protein * factor, carbs: carbs * factor,
                       fat: fat * factor, fiber: fiber * factor, sugar: sugar * factor, sodium: sodium * factor)
    }

    static func + (a: NutritionFacts, b: NutritionFacts) -> NutritionFacts {
        NutritionFacts(calories: a.calories + b.calories, protein: a.protein + b.protein, carbs: a.carbs + b.carbs,
                       fat: a.fat + b.fat, fiber: a.fiber + b.fiber, sugar: a.sugar + b.sugar, sodium: a.sodium + b.sodium)
    }
}

/// One food from the bundled table, built from USDA FoodData Central by Design/build_nutrition.py.
/// Nutrients are per 100 g.
struct FoodEntry: Decodable {
    let kcal: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    let fiber: Double
    let sugar: Double
    let sodium: Double
    /// Grams per millilitre, for volume measures such as cups.
    let density: Double?
    /// Grams of one medium item, such as an onion or a garlic clove.
    let each: Double?
    let slice: Double?

    var facts: NutritionFacts {
        NutritionFacts(calories: kcal, protein: protein, carbs: carbs, fat: fat, fiber: fiber, sugar: sugar, sodium: sodium)
    }
}

/// The bundled ingredient table, keyed by normalized ingredient name.
struct NutritionDatabase {
    static let shared: NutritionDatabase = {
        guard let url = Bundle.main.url(forResource: "nutrition", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let database = NutritionDatabase(data: data) else {
            return NutritionDatabase(foods: [:])
        }
        return database
    }()

    private let foods: [String: FoodEntry]

    init(foods: [String: FoodEntry]) {
        self.foods = foods
    }

    init?(data: Data) {
        guard let foods = try? JSONDecoder().decode([String: FoodEntry].self, from: data) else { return nil }
        self.foods = foods
    }

    /// Exact name first, then drops leading words so "fresh basil" finds "basil".
    func food(named name: String) -> FoodEntry? {
        var words = IngredientMatcher.normalize(name).split(separator: " ")
        while !words.isEmpty {
            if let food = foods[words.joined(separator: " ")] { return food }
            words.removeFirst()
        }
        return nil
    }
}

/// How much of an ingredient a measure stands for.
enum MeasureAmount: Equatable {
    case grams(Double)
    /// "To taste" or "for garnish": too little to affect the result.
    case negligible
    case unknown
}

enum MeasureParser {
    private static let weights: [String: Double] = [
        "g": 1, "gr": 1, "gm": 1, "gram": 1, "grams": 1, "kg": 1000, "kilo": 1000, "kilos": 1000,
        "oz": 28.35, "ounce": 28.35, "ounces": 28.35, "lb": 453.6, "lbs": 453.6, "pound": 453.6, "pounds": 453.6,
    ]
    private static let volumes: [String: Double] = [
        "ml": 1, "millilitre": 1, "millilitres": 1, "milliliter": 1, "milliliters": 1,
        "cl": 10, "dl": 100, "l": 1000, "litre": 1000, "litres": 1000, "liter": 1000, "liters": 1000,
        "cup": 240, "cups": 240, "pint": 473, "pints": 473, "quart": 946, "quarts": 946,
        "tbsp": 15, "tbs": 15, "tbsn": 15, "tblsp": 15, "tbls": 15, "tbl": 15, "tablespoon": 15, "tablespoons": 15,
        "tsp": 5, "tspn": 5, "teaspoon": 5, "teaspoons": 5,
    ]
    /// Rough weights for informal amounts.
    private static let informal: [String: Double] = [
        "pinch": 0.4, "pinches": 0.4, "dash": 0.6, "dashes": 0.6, "splash": 15, "drizzle": 10, "knob": 15,
        "handful": 30, "handfuls": 30, "bunch": 50, "bunches": 50, "sprig": 2, "sprigs": 2,
        "can": 400, "cans": 400, "tin": 400, "tins": 400, "packet": 200, "packets": 200, "pack": 200,
        "packs": 200, "package": 200, "bag": 200, "bags": 200, "jar": 350, "jars": 350,
        "rasher": 25, "rashers": 25, "fillet": 150, "fillets": 150, "leaf": 0.5, "leaves": 0.5,
        "for frying": 15, "to glaze": 5, "for brushing": 5, "for greasing": 2,
    ]
    private static let sizes: [String: Double] = ["small": 0.75, "medium": 1, "whole": 1, "large": 1.25]
    private static let negligiblePhrases = ["to taste", "garnish", "sprinkling", "sprinking", "spinkling", "dusting"]

    static func amount(of measure: String, food: FoodEntry) -> MeasureAmount {
        // Merged duplicates look like "1 clove + 2 cloves".
        let parts = measure.components(separatedBy: " + ").map { part(of: $0, food: food) }
        if parts.contains(.unknown) { return .unknown }
        let grams = parts.reduce(0.0) { total, amount in
            if case .grams(let value) = amount { return total + value }
            return total
        }
        return grams > 0 ? .grams(grams) : .negligible
    }

    private static func part(of measure: String, food: FoodEntry) -> MeasureAmount {
        let text = measure.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return .unknown }
        if negligiblePhrases.contains(where: text.contains) { return .negligible }

        // "Juice of 1", "Zest and juice of 2". Weights are for a typical lemon or lime.
        if let range = text.range(of: #"^(zest and juice|juice and zest|juice|zest) of\s*"#, options: .regularExpression) {
            let count = MeasureScaler.leadingQuantity(in: String(text[range.upperBound...]))?.value ?? 1
            return .grams(count * (text.hasPrefix("zest of") ? 3 : 40))
        }

        guard let (quantity, rest) = MeasureScaler.leadingQuantity(in: text) else {
            return informalAmount(text, food: food).map(MeasureAmount.grams) ?? .unknown
        }

        // "1 (14 oz) can" is one 14 oz can, but "2 (460g)" is 460 g in total.
        let trimmed = rest.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("("), let close = trimmed.firstIndex(of: ")") {
            let inner = String(trimmed[trimmed.index(after: trimmed.startIndex)..<close])
            let after = trimmed[trimmed.index(after: close)...].trimmingCharacters(in: .whitespaces)
            if case .grams(let grams) = part(of: inner, food: food) {
                return .grams(after.isEmpty ? grams : quantity * grams)
            }
        }

        guard let unit = trimmed.split(whereSeparator: { !$0.isLetter }).first.map(String.init) else {
            return count(quantity, size: 1, food: food)
        }
        if let grams = weights[unit] { return .grams(quantity * grams) }
        if let millilitres = volumes[unit] { return .grams(quantity * millilitres * (food.density ?? 1)) }
        if unit == "fl" { return .grams(quantity * 29.6 * (food.density ?? 1)) }
        if let size = sizes[unit] {
            // "2 large cans" is two cans, not two of the ingredient.
            if let grams = informalAmount(trimmed, food: food) { return .grams(quantity * grams) }
            return count(quantity, size: size, food: food)
        }
        if unit == "slice" || unit == "slices" { return .grams(quantity * (food.slice ?? 30)) }
        if unit == "stick" || unit == "sticks" { return .grams(quantity * (food.each ?? 113)) }
        if let grams = informal[unit] { return .grams(quantity * grams) }
        // "2 chopped", "1 clove peeled", "3 eggs".
        return count(quantity, size: 1, food: food)
    }

    private static func count(_ quantity: Double, size: Double, food: FoodEntry) -> MeasureAmount {
        guard let each = food.each else { return .unknown }
        return .grams(quantity * each * size)
    }

    private static func informalAmount(_ text: String, food: FoodEntry) -> Double? {
        if let phrase = informal[text] { return phrase }
        let words = text.split(whereSeparator: { !$0.isLetter }).map(String.init)
        for word in words {
            if let grams = informal[word] { return text.hasPrefix("small") ? grams * 0.6 : grams }
        }
        return nil
    }
}

/// Nutrition totals worked out from a recipe's ingredients.
struct NutritionEstimate: Equatable {
    /// Totals for the recipe at its original amounts.
    let total: NutritionFacts
    let knownIngredients: Int
    let countedIngredients: Int
    /// How many the recipe is assumed to serve at its original amounts.
    let defaultServings: Int
    /// A large ingredient has no nutrition data, so the total would be far too low.
    private let isMissingMajorIngredient: Bool

    /// Below this share of known ingredients the total would be too misleading to show.
    private static let minimumCoverage = 0.75
    /// An unmatched ingredient at least this heavy makes the total too low to show.
    private static let majorIngredientGrams = 50.0
    /// A plate takes up about this much oil however much is in the pan.
    private static let absorbedFryingOilGrams = 60.0
    private static let fryingOilThresholdGrams = 120.0
    /// Oils are close to pure fat, at about 884 kcal per 100 g.
    private static let oilCaloriesPer100g = 850.0
    /// Big batches get more servings than the usual four, so one serving stays believable.
    private static let caloriesPerAssumedServing = 800.0

    var isReliable: Bool {
        countedIngredients > 0
            && !isMissingMajorIngredient
            && Double(knownIngredients) / Double(countedIngredients) >= Self.minimumCoverage
            && total.calories > 0
    }

    init?(ingredients: [Ingredient], instructions: String, database: NutritionDatabase = .shared) {
        let isFried = instructions.range(of: #"(?i)\bfry|frying\b|\bfried\b"#, options: .regularExpression) != nil
        var total = NutritionFacts()
        var known = 0
        var counted = 0
        var missingMajor = false
        for ingredient in ingredients {
            guard let food = database.food(named: ingredient.name) else {
                switch MeasureParser.amount(of: ingredient.measure, food: Self.unmatchedFood) {
                case .negligible:
                    break
                case .grams(let grams):
                    counted += 1
                    if grams >= Self.majorIngredientGrams { missingMajor = true }
                case .unknown:
                    counted += 1
                    // "8" of something unmatched could be most of the dish.
                    if MeasureScaler.leadingQuantity(in: ingredient.measure) != nil { missingMajor = true }
                }
                continue
            }
            switch MeasureParser.amount(of: ingredient.measure, food: food) {
            case .grams(var grams):
                if isFried, food.kcal >= Self.oilCaloriesPer100g, grams > Self.fryingOilThresholdGrams {
                    grams = Self.absorbedFryingOilGrams
                }
                total = total + food.facts.multiplied(by: grams / 100)
                known += 1
                counted += 1
            case .negligible:
                break
            case .unknown:
                counted += 1
                // "8" of a food with no portion data, such as chops. Spices do have portion
                // data, so "2 cardamom pods" doesn't count.
                if food.density == nil, MeasureScaler.leadingQuantity(in: ingredient.measure) != nil {
                    missingMajor = true
                }
            }
        }
        guard counted > 0 else { return nil }
        self.total = total
        self.knownIngredients = known
        self.countedIngredients = counted
        self.isMissingMajorIngredient = missingMajor
        self.defaultServings = Self.stated(in: instructions)
            ?? min(max(4, Int((total.calories / Self.caloriesPerAssumedServing).rounded(.up))), 24)
    }

    /// Stands in for an ingredient with no data, to read its measure at about the density of water.
    private static let unmatchedFood = FoodEntry(kcal: 0, protein: 0, carbs: 0, fat: 0, fiber: 0, sugar: 0, sodium: 0,
                                                 density: nil, each: nil, slice: nil)

    /// TheMealDB rarely says how many a recipe serves, but some methods do.
    private static func stated(in instructions: String) -> Int? {
        let pattern = #"(?i)\b(?:serves|servings?:?|makes)\s+(\d{1,2})\b"#
        guard let range = instructions.range(of: pattern, options: .regularExpression) else { return nil }
        let digits = instructions[range].filter(\.isNumber)
        guard let count = Int(digits), (1...24).contains(count) else { return nil }
        return count
    }
}
