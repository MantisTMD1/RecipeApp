import Foundation

/// How much of a recipe to make. TheMealDB doesn't say how many people a recipe serves,
/// so amounts are scaled by a multiplier rather than a serving count.
enum RecipeScale: Double, CaseIterable, Identifiable {
    case half = 0.5, single = 1, double = 2, triple = 3

    var id: Double { rawValue }

    var title: String {
        switch self {
        case .half: "½×"
        case .single: "1×"
        case .double: "2×"
        case .triple: "3×"
        }
    }

    var accessibilityName: String {
        switch self {
        case .half: "Half"
        case .single: "Original amount"
        case .double: "Double"
        case .triple: "Triple"
        }
    }
}

extension Ingredient {
    func scaled(by factor: Double) -> Ingredient {
        guard factor != 1 else { return self }
        return Ingredient(name: name, measure: MeasureScaler.scale(measure, by: factor))
    }
}

/// Rescales the number at the start of a measure: "1 1/2 cups" × 2 → "3 cups",
/// "250ml" × 0.5 → "125ml", "½ tsp" × 3 → "1 ½ tsp". Text without a leading number
/// ("Pinch", "To taste") is left alone.
enum MeasureScaler {
    static func scale(_ measure: String, by factor: Double) -> String {
        // Merged duplicates look like "1 clove + 2 cloves"; scale each part.
        measure
            .components(separatedBy: " + ")
            .map { scalePart($0, by: factor) }
            .joined(separator: " + ")
    }

    private static let unicodeFractions: [Character: Double] = [
        "½": 0.5, "¼": 0.25, "¾": 0.75, "⅓": 1.0 / 3, "⅔": 2.0 / 3, "⅛": 0.125,
    ]

    // A quantity: "1", "1.5", "1/2", "1 1/2", "½", "1 ½", "1½", optionally a range "2-3".
    private static let quantity = #"(\d+(?:\.\d+)?\s*[½¼¾⅓⅔⅛]|\d+\s+\d+/\d+|\d+/\d+|\d+(?:\.\d+)?|[½¼¾⅓⅔⅛])"#
    private static let pattern = try! NSRegularExpression(
        pattern: "^\\s*" + quantity + "(?:\\s*(?:-|–|to)\\s*" + quantity + ")?")

    private static func scalePart(_ part: String, by factor: Double) -> String {
        let range = NSRange(part.startIndex..., in: part)
        guard let match = pattern.firstMatch(in: part, range: range),
              let whole = Range(match.range, in: part),
              let first = Range(match.range(at: 1), in: part),
              let low = parse(String(part[first])) else { return part }

        let rest = String(part[whole.upperBound...])
        // Grams and millilitres read better as whole numbers; everything else as fractions.
        let metric = rest.range(of: #"^\s*(g|kg|ml|l|grams?|millilitres?|milliliters?)\b"#,
                                options: [.regularExpression, .caseInsensitive]) != nil
        var text = format(low * factor, metric: metric)
        if let second = Range(match.range(at: 2), in: part), let high = parse(String(part[second])) {
            text += "-" + format(high * factor, metric: metric)
        }
        return text + rest
    }

    static func parse(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        // "1½" or "1 ½"
        if let last = trimmed.last, let fraction = unicodeFractions[last] {
            let whole = trimmed.dropLast().trimmingCharacters(in: .whitespaces)
            return (whole.isEmpty ? 0 : Double(whole) ?? 0) + fraction
        }
        // "1 1/2" or "1/2"
        let pieces = trimmed.split(separator: " ")
        var total = 0.0
        for piece in pieces {
            if piece.contains("/") {
                let nums = piece.split(separator: "/").compactMap { Double($0) }
                guard nums.count == 2, nums[1] != 0 else { return nil }
                total += nums[0] / nums[1]
            } else {
                guard let value = Double(piece) else { return nil }
                total += value
            }
        }
        return total
    }

    static func format(_ value: Double, metric: Bool) -> String {
        if metric || value >= 10 {
            let rounded = value.rounded()
            return String(Int(max(rounded, 1)))
        }
        let whole = Int(value)
        let remainder = value - Double(whole)
        // Snap to the nearest kitchen fraction.
        let options: [(Double, String)] = [(0, ""), (0.125, "⅛"), (0.25, "¼"), (1.0 / 3, "⅓"),
                                           (0.5, "½"), (2.0 / 3, "⅔"), (0.75, "¾"), (1, "")]
        let nearest = options.min { abs($0.0 - remainder) < abs($1.0 - remainder) }!
        let wholePart = whole + (nearest.0 == 1 ? 1 : 0)
        switch (wholePart, nearest.1) {
        case (0, ""): return "⅛"
        case (_, ""): return String(wholePart)
        case (0, let fraction): return fraction
        case (let w, let fraction): return "\(w) \(fraction)"
        }
    }
}
