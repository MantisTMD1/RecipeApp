import Foundation

/// The diets the user wants recipes filtered for, set in Settings.
/// TheMealDB doesn't label diets (apart from Vegetarian and Vegan categories), so recipes are
/// checked against their ingredient lists. This is a best-effort filter, not a guarantee.
struct DietFilter: Equatable, RawRepresentable {
    var vegetarian = false
    var vegan = false
    var glutenFree = false
    var dairyFree = false

    static let storageKey = "dietFilter"

    init() {}

    // Stored as a comma-separated string so it works with @AppStorage.
    init?(rawValue: String) {
        let parts = Set(rawValue.split(separator: ",").map(String.init))
        vegetarian = parts.contains("vegetarian")
        vegan = parts.contains("vegan")
        glutenFree = parts.contains("glutenFree")
        dairyFree = parts.contains("dairyFree")
    }

    var rawValue: String {
        [(vegetarian, "vegetarian"), (vegan, "vegan"), (glutenFree, "glutenFree"), (dairyFree, "dairyFree")]
            .filter(\.0).map(\.1).joined(separator: ",")
    }

    var isActive: Bool { vegetarian || vegan || glutenFree || dairyFree }

    /// "Vegetarian · Gluten-free", for showing which filters are on.
    var summary: String {
        [(vegan, "Vegan"), (vegetarian && !vegan, "Vegetarian"), (glutenFree, "Gluten-free"), (dairyFree, "Dairy-free")]
            .filter(\.0).map(\.1).joined(separator: " · ")
    }

    private var excludesMeat: Bool { vegetarian || vegan }

    /// TheMealDB categories that can never match (e.g. Beef for vegetarians).
    func allowsCategory(_ category: String) -> Bool {
        if excludesMeat && Self.meatCategories.contains(category) { return false }
        return true
    }

    func allows(_ meal: Meal) -> Bool {
        guard isActive else { return true }
        if let category = meal.category, !allowsCategory(category) { return false }
        let names = meal.ingredients.map { Self.normalize($0.name) }
        if excludesMeat && names.contains(where: { Self.matches($0, Self.meat, except: Self.meatExceptions) }) { return false }
        if vegan && names.contains(where: { Self.matches($0, Self.animalProducts, except: Self.dairyExceptions) }) { return false }
        if dairyFree && names.contains(where: { Self.matches($0, Self.dairy, except: Self.dairyExceptions) }) { return false }
        if glutenFree && (meal.category == "Pasta"
                          || names.contains(where: { Self.matches($0, Self.gluten, except: Self.glutenExceptions) })) { return false }
        return true
    }

    // MARK: Ingredient lists

    static let meatCategories: Set<String> = ["Beef", "Chicken", "Lamb", "Pork", "Seafood", "Goat"]

    private static let meat: [String] = [
        "beef", "steak", "sirloin", "brisket", "oxtail", "veal", "chicken", "pork", "bacon", "ham", "gammon",
        "lamb", "mutton", "goat", "venison", "rabbit", "duck", "turkey", "goose", "pheasant", "quail",
        "sausage", "chorizo", "salami", "pepperoni", "prosciutto", "pancetta", "lardons", "lard", "suet",
        "meatballs", "liver", "kidneys", "gelatine", "gelatin", "bone marrow",
        "fish", "salmon", "tuna", "cod", "haddock", "mackerel", "sardine", "anchovy", "anchovies", "trout",
        "tilapia", "halibut", "monkfish", "kipper", "herring", "prawn", "shrimp", "crab", "lobster",
        "mussel", "clam", "oyster", "scallop", "squid", "octopus", "calamari", "worcestershire", "bonito",
    ]
    private static let meatExceptions = ["kidney bean", "goats cheese", "goat cheese", "goats milk", "goat milk"]

    private static let dairy: [String] = [
        "milk", "butter", "buttermilk", "cream", "cheese", "cheddar", "parmesan", "parmigiano", "mozzarella",
        "feta", "ricotta", "mascarpone", "gruyere", "brie", "halloumi", "paneer", "ghee", "yogurt", "yoghurt",
        "custard", "creme fraiche", "whey", "quark", "fromage frais", "stilton", "gorgonzola", "camembert",
        "emmental", "pecorino", "goats cheese", "condensed",
    ]
    private static let dairyExceptions = [
        "peanut butter", "almond butter", "cashew butter", "cocoa butter", "butter bean", "coconut milk",
        "coconut cream", "creamed coconut", "almond milk", "soy milk", "soya milk", "oat milk", "rice milk",
        "cream of tartar", "vegetable milk", "oat cream", "soy cream", "vegan", "dairy free", "plant based",
    ]
    private static let animalProducts = dairy + ["egg", "yolk", "honey", "mayonnaise", "meringue"]

    private static let gluten: [String] = [
        "flour", "bread", "breadcrumb", "breadcrumbs", "panko", "pasta", "spaghetti", "macaroni", "penne",
        "fusilli", "rigatoni", "linguine", "fettuccine", "tagliatelle", "lasagne", "lasagna", "farfalle", "orzo",
        "ravioli", "tortellini", "noodle", "noodles", "vermicelli", "couscous", "bulgur", "semolina", "wheat",
        "barley", "rye", "spelt", "pastry", "filo", "phyllo", "dough", "biscuit", "cracker", "digestive",
        "croissant", "baguette", "pitta", "pita", "naan", "tortilla", "soy sauce", "beer", "ale", "stout",
        "malt", "seitan", "bun", "brioche", "ciabatta", "pizza",
    ]
    private static let glutenExceptions = [
        "rice flour", "corn flour", "cornflour", "almond flour", "coconut flour", "gram flour", "chickpea flour",
        "buckwheat", "potato flour", "tapioca flour", "cassava flour", "arrowroot", "rice noodle",
        "rice vermicelli", "glass noodle", "corn tortilla", "gluten free", "tamari", "ginger ale",
    ]

    // MARK: Matching

    /// Lowercase, accents removed, punctuation turned into spaces: "Crème Fraîche" → "creme fraiche".
    static func normalize(_ name: String) -> String {
        let folded = name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let cleaned = folded.unicodeScalars.map { CharacterSet.letters.contains($0) ? Character($0) : " " }
        return String(cleaned).split(separator: " ").joined(separator: " ")
    }

    /// Whole-word match, allowing simple plurals ("prawn" matches "king prawns").
    private static func matches(_ name: String, _ keywords: [String], except exceptions: [String]) -> Bool {
        let padded = " \(name) "
        if exceptions.contains(where: { padded.contains(" \($0)") }) { return false }
        return keywords.contains { keyword in
            padded.contains(" \(keyword) ") || padded.contains(" \(keyword)s ") || padded.contains(" \(keyword)es ")
        }
    }
}
